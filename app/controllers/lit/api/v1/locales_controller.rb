require_dependency 'lit/api/v1/base_controller'

module Lit
  module API
    module V1
      class LocalesController < API::V1::BaseController
        def index
          @locales = Locale.all
          render json: @locales.as_json(root: false, only: %i[id locale])
        end
      end
    end
  end
end
