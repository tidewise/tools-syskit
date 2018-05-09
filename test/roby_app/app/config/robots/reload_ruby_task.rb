Robot.requires do
    require 'models/compositions/reload_ruby_task'
    Syskit.conf.use_ruby_tasks SyskitUnitTests::Compositions::ReloadRubyTask => 'task'
end

class Interface < Roby::Interface::CommandLibrary
    def orogen_model_reloaded?
        return !!SyskitUnitTests::Compositions::ReloadRubyTask.find_output_port('test'),
            "reloaded model was expected to have a 'test' output port, but does not"
    end

    def orogen_deployment_exists?
        reload_model = SyskitUnitTests::Compositions::ReloadRubyTask
        result = Syskit.conf.each_configured_deployment.any? do |d|
            d.each_orogen_deployed_task_context_model.any? do |t|
                (t.task_model == reload_model.orogen_model) && t.name == 'task'
            end
        end

        return result, "could not find the 'task' task of model #{reload_model}"
    end
end
Roby::Interface::Interface.subcommand 'unit_tests',
    Interface, 'Commands used by unit tests'