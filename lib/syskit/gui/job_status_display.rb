require 'syskit/gui/job_state_label'
module Syskit
    module GUI
        class JobStatusDisplay < Qt::Widget
            attr_reader :job

            attr_reader :ui_job_actions
            attr_reader :ui_start
            attr_reader :ui_restart
            attr_reader :ui_drop
            attr_reader :ui_state

            def initialize(job, batch_manager, job_item_model)
                super(nil)
                @batch_manager = batch_manager
                @job = job
                @job_item_model = job_item_model
                @job_item_info  = job_item_model.fetch_job_info(job.job_id)
                @ui_summaries_labels = Hash.new
                connect @job_item_info, SIGNAL('job_summary_updated()'),
                    self, SLOT('update_notification_summaries()')

                create_ui
                connect_to_hooks
            end

            def remove
                @job_item_model.remove_job(job.job_id)
            end

            INTERMEDIATE_TERMINAL_STATES = [
                Roby::Interface::JOB_SUCCESS.upcase.to_s,
                Roby::Interface::JOB_DROPPED.upcase.to_s,
                Roby::Interface::JOB_FAILED.upcase.to_s,
                Roby::Interface::JOB_PLANNING_FAILED.upcase.to_s
            ]

            def label
                "##{job.job_id} #{job.action_name}"
            end

            class AutoHeightList < Qt::ListView
                attr_reader :max_row_count

                def initialize(*)
                    super
                    @last_row_count = 0
                    @max_row_count = Float::INFINITY
                end

                def show_all_rows
                    self.max_row_count = Float::INFINITY
                end

                def max_row_count=(count)
                    @max_row_count = count
                    update_geometry_if_needed
                end

                def update_geometry_if_needed
                    count = model.rowCount(root_index)
                    count = [@max_row_count, count].min
                    if count == 0
                        hide
                    elsif @last_row_count == 0
                        show
                        update_geometry
                    elsif count != @last_row_count
                        update_geometry
                    end
                    @last_row_count = count
                end
                slots 'update_geometry_if_needed()'

                def sizeHint
                    count = [@max_row_count, model.rowCount(root_index)].min
                    @last_row_count = count
                    Qt::Size.new(sizeHintForColumn(0),
                        (count + 0.25) * sizeHintForRow(0))
                end
            end

            def create_ui
                self.focus_policy = Qt::ClickFocus

                header_layout    = Qt::HBoxLayout.new
                @ui_job_actions  = Qt::Widget.new
                @ui_events_actions_layout = Qt::HBoxLayout.new

                header_layout.add_widget(@ui_state = JobStateLabel.new(name: label), 10)
                header_layout.add_stretch(1)
                header_layout.add_widget(@ui_job_actions)
                header_layout.add_stretch(1)
                header_layout.add_layout(@ui_events_actions_layout)
                header_layout.set_contents_margins(0, 0, 0, 0)

                @ui_state.size_policy = Qt::SizePolicy.new(
                    Qt::SizePolicy::Expanding, Qt::SizePolicy::Preferred)

                ui_job_actions_layout = Qt::HBoxLayout.new(@ui_job_actions)
                @actions_buttons = Hash[
                    'Drop'        => Qt::PushButton.new("Drop", self),
                    'Restart'     => Qt::PushButton.new("Restart", self),
                    "Start Again" => Qt::PushButton.new("Start Again", self)
                ]
                ui_job_actions_layout.add_widget(
                    @ui_drop    = @actions_buttons['Drop'])
                ui_job_actions_layout.add_widget(
                    @ui_restart = @actions_buttons['Restart'])
                ui_job_actions_layout.add_widget(
                    @ui_start   = @actions_buttons['Start Again'])
                ui_job_actions_layout.set_contents_margins(0, 0, 0, 0)
                ui_start.hide

                @ui_events_actions_layout.set_contents_margins(0, 0, 0, 0)
                @ui_events_actions_layout.add_widget(
                    @ui_events_actions_label = Qt::Label.new("<b>Events</b>"))
                @ui_events_actions_layout.add_widget(
                    @ui_last_5 = Qt::PushButton.new("Last 5"))
                @ui_events_actions_layout.add_widget(
                    @ui_last_10s = Qt::PushButton.new("Last 10s"))
                @ui_events_actions_layout.add_widget(
                    @ui_all_events = Qt::PushButton.new("All"))
                @ui_events_actions_layout.add_stretch()
                @ui_events_actions_label.style_sheet =
                    @ui_last_10s.style_sheet =
                    @ui_last_5.style_sheet =
                    @ui_all_events.style_sheet = "QPushButton { font-size: 10pt }"
                @ui_last_5.flat = true
                @ui_last_5.checkable = true
                @ui_last_10s.flat = true
                @ui_last_10s.checkable = true
                @ui_all_events.flat = true
                @ui_all_events.checkable = true
                @ui_last_5.connect(SIGNAL('clicked(bool)')) do |toggled|
                    if toggled
                        @ui_events.show
                        @ui_last_10s.checked = false
                        @ui_all_events.checked = false
                        @event_filter.show_all
                        @ui_events.max_row_count = 5
                        @ui_events.update_geometry_if_needed
                    else
                        @ui_events.max_row_count = 0
                    end
                end
                @ui_last_10s.connect(SIGNAL('clicked(bool)')) do |toggled|
                    if toggled
                        @ui_events.show
                        @ui_last_5.checked = false
                        @ui_all_events.checked = false
                        @event_filter.timeout = 10
                        @ui_events.max_row_count = Float::INFINITY
                        @ui_events.update_geometry_if_needed
                    else
                        @ui_events.max_row_count = 0
                    end
                end
                @ui_all_events.connect(SIGNAL('clicked(bool)')) do |toggled|
                    if toggled
                        @ui_events.show
                        @ui_last_5.checked = false
                        @ui_last_10s.checked = false
                        @event_filter.show_all
                        @ui_events.max_row_count = Float::INFINITY
                        @ui_events.update_geometry_if_needed
                    else
                        @ui_events.max_row_count = 0
                    end
                end


                @ui_events = AutoHeightList.new(self)
                @ui_events.edit_triggers = Qt::AbstractItemView::NoEditTriggers
                @ui_events.vertical_scroll_bar_policy = Qt::ScrollBarAlwaysOff
                @ui_events.horizontal_scroll_bar_policy = Qt::ScrollBarAlwaysOff
                @ui_events.size_policy = Qt::SizePolicy.new(
                    Qt::SizePolicy::Preferred, Qt::SizePolicy::Minimum)
                @ui_events.style_sheet = <<-STYLESHEET
                QListView {
                    font-size: 10pt;
                    padding: 3;
                    border: none;
                    background: transparent;
                }
                STYLESHEET
                @event_filter = @job_item_info.display_notifications_on_list(@ui_events)
                @event_filter.show_all
                connect(@ui_events.model,
                    SIGNAL('rowsInserted(const QModelIndex&, int, int)'),
                    @ui_events, SLOT('update_geometry_if_needed()'))
                connect(@ui_events.model,
                    SIGNAL('rowsRemoved(const QModelIndex&, int, int)'),
                    @ui_events, SLOT('update_geometry_if_needed()'))

                vlayout = Qt::VBoxLayout.new(self)
                vlayout.add_layout header_layout
                @ui_summaries = Qt::VBoxLayout.new
                @ui_summaries.set_contents_margins(0, 0, 0, 0)
                vlayout.add_layout @ui_summaries
                vlayout.add_widget @ui_events

                @ui_events.max_row_count = 0
                if job.state
                    ui_state.update_state(job.state.upcase)
                end
            end

            def update_current_time(time)
                @event_filter.update_deadline(time)
            end

            def keyPressEvent(event)
                make_actions_immediate(event.key == Qt::Key_Control)
                super
            end

            def keyReleaseEvent(event)
                make_actions_immediate(false)
                super
            end

            def make_actions_immediate(enable)
                @actions_immediate = enable
                if enable
                    @actions_buttons.each do |text, btn|
                        btn.text = "#{text} Now"
                    end
                else
                    @actions_buttons.each do |text, btn|
                        btn.text = text
                    end
                end
            end

            def show_job_actions
                ui_job_actions.show
            end

            def hide_job_actions
                ui_job_actions.hide
            end

            def mousePressEvent(event)
                emit clicked
                event.accept
            end
            def mouseReleaseEvent(event)
                event.accept
            end
            signals 'clicked()'

            def connect_to_hooks
                ui_drop.connect(SIGNAL('clicked()')) do
                    @batch_manager.drop_job(self)
                    if @actions_immediate
                        @batch_manager.process
                    end
                end
                ui_restart.connect(SIGNAL('clicked()')) do
                    arguments = job.action_arguments.dup
                    arguments.delete(:job_id)
                    if @batch_manager.create_new_job(job.action_name, arguments)
                        @batch_manager.drop_job(self)
                        if @actions_immediate
                            @batch_manager.process
                        end
                    end
                end
                ui_start.connect(SIGNAL('clicked()')) do
                    arguments = job.action_arguments.dup
                    arguments.delete(:job_id)
                    if @batch_manager.create_new_job(job.action_name, arguments)
                        if @actions_immediate
                            @batch_manager.process
                        end
                    end
                end
                job.on_progress do |state|
                    update_state(state)
                end
                job.on_exception do |kind, exception|
                end
            end

            def update_state(state)
                if INTERMEDIATE_TERMINAL_STATES.include?(ui_state.current_state)
                    ui_state.update_state(
                        "#{ui_state.current_state},
                            #{state.upcase}",
                        color: ui_state.current_color)
                else
                    ui_state.update_state(state.upcase)
                end

                if state == Roby::Interface::JOB_DROPPED
                    ui_drop.hide
                    ui_restart.hide
                    ui_start.show
                elsif Roby::Interface.terminal_state?(state)
                    ui_drop.hide
                    ui_restart.hide
                    ui_start.show
                end
            end

            def update_summary(key, messages, extended_info: [])
                messages = messages
                extended_info = extended_info
                labels = @ui_summaries_labels[key] || Array.new

                if labels.empty?
                    last_label_index = @ui_summaries.count
                else
                    last_label_index = @ui_summaries.index_of(labels.last)
                end
                while labels.size < messages.size
                    n = Qt::Label.new(self)
                    labels << n
                    @ui_summaries.insert_widget(last_label_index, n)
                    last_label_index += 1
                end
                while labels.size > messages.size
                    l = labels.pop
                    @ui_summaries.remove_widget(l)
                    l.dispose
                end
                @ui_summaries_labels[key] = labels

                labels.zip(messages, extended_info).map do |label, text, info|
                    label.text = "<small>#{text}</small>"
                    label.tool_tip = info || ""
                    label
                end
            end

            def remove_summary(key)
                update_summary(key, [])
            end

            def update_notification_summaries
                update_summary_execution_agents_not_ready
                update_summary_fatal_exceptions
                update_summary_scheduler_holdoff
            end
            slots 'update_notification_summaries()'

            def update_summary_execution_agents_not_ready
                agents = @job_item_info.execution_agents
                not_ready = agents.each_key.
                    find_all { |a| !a.ready_event.emitted? }
                if not_ready.size == 0
                    remove_summary('execution_agents_not_ready')
                else
                    all_supported_roles = Set.new
                    full_info = not_ready.map do |agent_task|
                        supported_roles = agents[agent_task]
                        all_supported_roles.merge(supported_roles)
                        "Agent of #{supported_roles.sort.join(", ")}:\n  " +
                            PP.pp(agent_task, '').split("\n").join("\n  ")
                    end.join("\n")

                    update_summary('execution_agents_not_ready',
                        ["#{not_ready.size} execution agents are not ready, supporting "\
                        "#{all_supported_roles.size} tasks in this job: "\
                        "#{all_supported_roles.sort.join(", ")}"],
                        extended_info: [full_info])
                end
            end

            def update_summary_fatal_exceptions
                messages = @job_item_info.notifications_by_type(
                    JobItemModel::NOTIFICATION_EXCEPTION_FATAL)
                messages = messages.values.flatten.reverse
                summary = ["#{messages.size} exceptions"] +
                    messages.map { |m| "&nbsp;&nbsp;#{m.message}" }
                extended = [""] + messages.map(&:extended_message)

                if messages.size == 0
                    remove_summary('exceptions')
                else
                    update_summary('exceptions', summary,
                        extended_info: extended)
                end
            end

            def update_summary_scheduler_holdoff
                holdoff_messages = @job_item_info.notifications_by_type(
                    JobItemModel::NOTIFICATION_SCHEDULER_HOLDOFF)
                holdoff_count = holdoff_messages.size
                if holdoff_count == 0
                    remove_summary('scheduler_holdoff')
                else
                    full_info = holdoff_messages.values.flatten.
                        map(&:message).join("\n")
                    update_summary('scheduler_holdoff',
                        ["#{holdoff_count} tasks cannot be scheduled: "\
                        "#{holdoff_messages.keys.sort.join(", ")}"],
                        extended_info: [full_info])
                end
            end
        end
    end
end
