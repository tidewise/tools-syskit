require 'roby/app/gen'
class SrvGenerator < Roby::App::GenModelClass
    def initialize(runtime_args, runtime_options = Hash.new)
        @model_type = 'services'
        super
    end

    def has_test?; false end
end

