require 'test_helper'

module Lit
  class API::V1::LocalizationKeysControllerTest < ActionController::TestCase
    def setup
      Lit::Localization.delete_all
      Lit::LocalizationKey.delete_all
      Lit::LocalizationVersion.delete_all
      Lit.loader = nil
      Lit.api_enabled = true
      Lit.api_key = 'test'
      Lit::Engine.routes.clear!
      Dummy::Application.reload_routes!
      @routes = Lit::Engine.routes
      request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Token.encode_credentials('test')
      Lit.ignore_yaml_on_startup = false
      Lit.init
    end

    def teardown
      Lit.ignore_yaml_on_startup = nil
    end

    test 'should get index' do
      get :index, format: :json
      assert_response :success
    end

    test 'should only changed records' do
      I18n.l(Time.now)
      Lit::LocalizationKey.update_all ['updated_at=?', 2.hours.ago]
      Lit::Localization.update_all ['updated_at=?', 2.hours.ago]
      l = Lit::LocalizationKey.last
      l.touch
      l.localizations.each do |loc|
        loc.update_column :is_changed, true
      end
      get :index, params: { format: :json, after: I18n.l(2.seconds.ago) }
      assert_response :success
      assert_equal 1, assigns(:localization_keys).count
      assert response.body =~ /#{l.localization_key}/
    end
  end
end
