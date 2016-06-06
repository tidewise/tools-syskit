module Syskit
    module Runtime
        module PlanExtension
            # The thread pool used to resolve Syskit networks asynchronously
            #
            # @return [Concurrent::CachedThreadPool]
            attr_accessor :syskit_resolution_pool

            # The currently running resolution
            #
            # @return [NetworkGeneration::Async,nil]
            attr_accessor :syskit_current_resolution

            # A transaction used to protect all Syskit components from the plan
            # GC during resolution
            attr_accessor :syskit_current_resolution_keepalive

            # True if Syskit is currently resolving a network
            def syskit_has_async_resolution?
                !!@syskit_current_resolution
            end

            # Start the resolution of the network generated by the given
            # requirement tasks
            #
            #
            # @param [Array<InstanceRequirementsTask>] requirement_tasks
            # @raise [RuntimeError] if there is already a resolution. Call
            #   {#syskit_cancel_async_resolution} first
            # @return [void]
            def syskit_start_async_resolution(requirement_tasks)
                if syskit_has_async_resolution?
                    raise ArgumentError, "an async resolution is already running, call #syskit_cancel_async_resolution first"
                end

                @syskit_resolution_pool ||= Concurrent::CachedThreadPool.new
                # Protect all toplevel Syskit tasks while the resolution runs
                @syskit_current_resolution_keepalive = Roby::Transaction.new(self)
                find_local_tasks(Component).each do |component_task|
                    if !component_task.finished?
                        syskit_current_resolution_keepalive.wrap(component_task)
                    end
                end
                @syskit_current_resolution = NetworkGeneration::Async.new(self, thread_pool: syskit_resolution_pool)
                syskit_current_resolution.start(requirement_tasks)
            end

            # Cancels the currently running resolution
            def syskit_cancel_async_resolution
                syskit_current_resolution.cancel
                syskit_current_resolution_keepalive.discard_transaction
                @syskit_current_resolution = nil
            end

            # True if the async part of the current resolution is finished
            def syskit_finished_async_resolution?
                syskit_current_resolution.finished?
            end

            # True if the currently running resolution is valid w.r.t. the
            # current plan's state
            def syskit_valid_async_resolution?
                syskit_current_resolution.valid?
            end

            # Wait for the current running resolution to finish, and apply it on
            # the plan
            def syskit_join_current_resolution
                syskit_current_resolution.join
                Runtime.apply_requirement_modifications(self)
            end

            # Apply a finished resolution on this plan
            #
            # @raise [RuntimeError] if the current resolution is not finished.
            def syskit_apply_async_resolution_results
                if !syskit_finished_async_resolution?
                    raise RuntimeError, "the current network resolution is not yet finished"
                end

                begin
                    syskit_current_resolution.apply
                ensure
                    syskit_current_resolution_keepalive.discard_transaction
                    @syskit_current_resolution = nil
                end
            end
        end

        def self.apply_requirement_modifications(plan, force: false)
            if plan.syskit_has_async_resolution?
                # We're already running a resolution, make sure it is not
                # obsolete
                if force || !plan.syskit_valid_async_resolution?
                    plan.syskit_cancel_async_resolution
                elsif plan.syskit_finished_async_resolution?
                    running_requirement_tasks = plan.find_tasks(Syskit::InstanceRequirementsTask).running
                    begin
                        plan.syskit_apply_async_resolution_results
                    rescue ::Exception => e
                        running_requirement_tasks.each do |t|
                            t.failed_event.emit(e)
                        end
                        return
                    end
                    running_requirement_tasks.each do |t|
                        t.success_event.emit
                    end
                    return
                end
            end

            if !plan.syskit_has_async_resolution?
                if force || plan.find_tasks(Syskit::InstanceRequirementsTask).running.any? { true }
                    requirement_tasks = NetworkGeneration::Engine.discover_requirement_tasks_from_plan(plan)
                    if !requirement_tasks.empty?
                        # We're not resolving anything, but new IR tasks have been
                        # started. Deploy them
                        plan.syskit_start_async_resolution(requirement_tasks)
                    end
                end
            end
        end
    end
end

Roby::ExecutablePlan.include Syskit::Runtime::PlanExtension
