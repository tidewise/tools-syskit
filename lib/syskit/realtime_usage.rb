module Syskit

    class RealtimeHandler
        #This is a counter for the plan-iteration
        #maping is idx -> Time
        attr_reader :plan_iteration

        #This Map holds all started tasks
        #mapping is model -> [[iteration,task]]
        attr_reader :start_points
        
        #This Map holds all stopped tasks
        #mapping is model -> [[iteration,task]]
        attr_reader :stop_points
        
        #This Map holds all reconfigurd tasks
        #mapping is model -> [[iteration,old-task,new-task]]
        attr_reader :reconfigure_points
        
        #This Map holds all created connections 
        #mapping is model -> [[iteration,from-task,to-task,options]]
        attr_reader :created_connections
        
        #This Map holds all reconfigures connections
        #mapping is model -> [[iteration,from-task,to-task,options]]
        attr_reader :reconfigured_connections
        
        #This Map holds all released connections 
        #mapping is source-task-model -> [[iteration,from-task,to-task,ports,options]]
        attr_reader :released_connections


        def initialize
            @plan_iteration = Array.new
            @start_points = Hash.new
            @stop_points = Hash.new
            @reconfigure_points = Hash.new
            @created_connections = Hash.new
            @reconfigured_connections = Hash.new
            @released_connections = Hash.new
        end

        def create_plan_iteration(time = Time.new)
            plan_iteration << time
            current_iteration
        end

        def current_iteration
            plan_iteration.size
        end
        
        def add_connections(from,to,ports,time)
            model = from
            model = from.model if from.respond_to?("model")
            created_connections[model] = Array.new if created_connections[model].nil?
            created_connections[model] << [time,from,to,ports] 
        end
        
        def remove_connections(from,to,ports,time)
            model = from
            model = from.model if from.respond_to?("model")
            removed_connections[model] = Array.new if removed_connections[model].nil?
            removed_connections[model] << [time,from,to,ports] 
        end

        def add_task_start_point(task, iteration)
            add_task_to_runtime_change(@start_points,task,iteration)
        end
        
        def add_task_stop_point(task, iteration)
            add_task_to_runtime_change(@stop_points,task,iteration)
        end

        def add_task_reconfigurarion(task,iteration)
           @reconfigure_points[task.model] = Array.new if @reconfigure_points[task.model].nil?
           begin
           @reconfigure_points[task.model] << [iteration,task,task] #TODO Change task,task to old-task,new-task
           rescue Exception => e
               binding.pry
           end
        end

        def known_task_models
            (@start_points.keys | @stop_points.keys).uniq
        end
        
        #Return the tasks that were stopped during the last Syskit cycle iteration
        def started_tasks(from =current_iteration-1 ,to= current_iteration) 
            res = Array.new
            @start_points.each_pair do |key,value|
                #iterating over all possible stop-points
                value.each do |sp,task|
#                    binding.pry
                    if(sp > from and sp <= current_iteration)
                        res << task
                    end
                end
            end
            res
        end
        
        #Return the tasks that were stopped during the last Syskit cycle iteration
        def was_started(model, from =current_iteration-1 ,to= current_iteration) 
            return false if not @start_points[model]
            res = Array.new
            @start_points[model].each do |sp,task|
                if(sp > from and sp <= current_iteration)
                   return true 
                end
            end
            false
        end
        
        #Return the tasks that were stopped during the last Syskit cycle iteration
        def stopped_tasks(from =current_iteration-1 ,to= current_iteration) 
            res = Array.new
            @stop_points.each_pair do |key,value|
                #iterating over all possible stop-points
                value.each do |sp,task|
#                    binding.pry
                    if(sp > from and sp <= current_iteration)
                        res << task
                    end
                end
            end
            res
        end
        
        #Return the tasks that were stopped during the last Syskit cycle iteration
        def was_stopped(model, from =current_iteration-1 ,to= current_iteration) 
            return false if not @stop_points[model]
            res = Array.new
            @stop_points[model].each do |sp,task|
                if(sp > from and sp <= current_iteration)
                   return true 
                end
            end
            false
        end
        

        #return the start indicies for a given task
        def start_indexes(task)
            runtime_change_indexes(@start_points,task)
        end
        
        #return the start indicies for a given task
        def stop_indexes(task)
            runtime_change_indexes(@stop_points,task)
        end
        
        def reconfigure_indexes(task)
            runtime_change_indexes(@reconfigure_points,task)
        end


        ############## Helper functions not called from outside ####################
        
        def add_task_to_runtime_change(array,task,iteration)
            if(array[task.model].nil?)
                array[task.model] = Array.new
            end
            array[task.model] <<  [iteration,task]
        end

        
        
        def runtime_change_indexes(list,model)
            if model.respond_to?("model") #Assume we got a task and not a model
                model = model.model
            end
            a = Array.new
            list[model].to_a.each do |iteration,task|
                a << iteration
            end
            a
        end
    end
    
    
    Realtime = RealtimeHandler.new
end
