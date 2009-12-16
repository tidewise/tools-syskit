BASE_DIR = File.expand_path( '../..', File.dirname(__FILE__))
APP_DIR = File.join(BASE_DIR, "test")
$LOAD_PATH.unshift BASE_DIR
require 'test/roby/common'

class TC_RobySpec_Composition < Test::Unit::TestCase
    include RobyPluginCommonTest

    def simple_composition
        sys_model.subsystem "simple" do
            add SimpleSource::Source, :as => 'source'
            add SimpleSink::Sink, :as => 'sink'

            add Echo::Echo
            add Echo::Echo, :as => 'echo'
            add Echo::Echo, :as => :echo
        end
    end

    def test_simple_composition_definition
        subsys = simple_composition
        assert_equal sys_model, subsys.system
        assert(subsys < Orocos::RobyPlugin::Composition)
        assert_equal "simple", subsys.name

        assert_equal ['Echo', 'echo', 'source', 'sink'].to_set, subsys.children.keys.to_set
        expected_models = [Echo::Echo, Echo::Echo, SimpleSource::Source, SimpleSink::Sink]
        assert_equal expected_models.to_set, subsys.children.values.to_set
    end

    def test_simple_composition_autoconnection
        subsys = sys_model.subsystem("source_sink") do
            add SimpleSource::Source, :as => "source"
            add SimpleSink::Sink, :as => "sink"
            autoconnect
        end
        subsys.compute_autoconnection

        assert_equal({%w{source sink} => {%w{cycle cycle} => {}}},
            subsys.connections)
    end

    def test_simple_composition_ambiguity
        subsys = sys_model.subsystem("source_sink0") do
            add SimpleSource::Source, :as => 'source'
            add SimpleSink::Sink, :as => 'sink1'
            add SimpleSink::Sink, :as => 'sink2'
            autoconnect
        end
        subsys.compute_autoconnection

        subsys = sys_model.subsystem("source_sink1") do
            add Echo::Echo, :as => 'echo1'
            add Echo::Echo, :as => 'echo2'
            autoconnect
        end
        assert_raises(Ambiguous) { subsys.compute_autoconnection }

        subsys = sys_model.subsystem("source_sink2") do
            add SimpleSource::Source, :as => 'source1'
            add SimpleSource::Source, :as => 'source2'
            add SimpleSink::Sink, :as => 'sink1'
            autoconnect
        end
        assert_raises(Ambiguous) { subsys.compute_autoconnection }
    end

    def test_composition_port_export
        source, sink1, sink2 = nil
        subsys = sys_model.subsystem("source_sink0") do
            source = add SimpleSource::Source, :as => 'source'
            sink1  = add SimpleSink::Sink, :as => 'sink1'
            sink2  = add SimpleSink::Sink, :as => 'sink2'
        end
            
        subsys.export sink1.cycle
        assert_equal(sink1.cycle, subsys.port('cycle'))
        assert_raises(SpecError) { subsys.export(sink2.cycle) }
        
        subsys.export sink2.cycle, :as => 'cycle2'
        assert_equal(sink1.cycle, subsys.port('cycle'))
        assert_equal(sink2.cycle, subsys.port('cycle2'))
        assert_equal(sink1.cycle, subsys.cycle)
        assert_equal(sink2.cycle, subsys.cycle2)
    end

    def test_composition_port_export_instanciation
        source, sink1, sink2 = nil
        subsys = sys_model.subsystem("source_sink0") do
            source = add SimpleSource::Source, :as => 'source'
            sink1  = add SimpleSink::Sink, :as => 'sink1'
        end
            
        subsys.export source.cycle, :as => 'out_cycle'
        subsys.export sink1.cycle, :as => 'in_cycle'

        orocos_engine    = Engine.new(plan, sys_model)
        orocos_engine.add(Compositions::SourceSink0)
        orocos_engine.instanciate

        tasks = plan.find_tasks(Compositions::SourceSink0).
            with_child(SimpleSink::Sink, Flows::DataFlow, ['in_cycle', 'cycle'] => Hash.new).
            with_parent(SimpleSource::Source, Flows::DataFlow, ['cycle', 'out_cycle'] => Hash.new).
            to_a
        assert_equal 1, tasks.size
    end

    def test_composition_explicit_connection
        source, sink1, sink2 = nil
        subsys = sys_model.subsystem("source_sink0") do
            source = add SimpleSource::Source, :as => 'source'
            sink1  = add SimpleSink::Sink, :as => 'sink1'
            sink2  = add SimpleSink::Sink, :as => 'sink2'

            connect source.cycle => sink1.cycle
            connect source.cycle => sink2.cycle
        end
    end
end

