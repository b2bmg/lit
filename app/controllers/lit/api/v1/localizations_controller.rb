module Lit
  class API::V1::LocalizationsController < API::V1::BaseController
    def index
      @localizations = fetch_localizations
      render json:
               @localizations.as_json(
                 root: false,
                 only: %i[id localization_key_id locale_id],
                 methods: %i[value localization_key_str locale_str localization_key_is_deleted],
               )
    end

    def last_change
      @localization = Localization.order(updated_at: :desc).first
      render json: @localization.as_json(root: false, only: [], methods: [:last_change])
    end

    private

    def fetch_localizations
      scope = Localization.includes(:locale, :localization_key)

      if params[:after].present?
        after_date = Time.parse("#{params[:after]} #{Time.zone.name}").in_time_zone
        scope.after(after_date).to_a
      else
        scope.all
      end
    end
  end
end
