module Lit
  class LocalizationKeysController < ::Lit::ApplicationController
    before_action :find_localization_scope, except: %i[destroy find_localization]
    before_action :find_localization_key, only: %i[star destroy change_completed restore_deleted]

    def index
      get_localization_keys
    end

    def not_translated
      @scope = @scope.not_completed
      get_localization_keys
    end

    def visited_again
      @scope = @scope.unscope(where: :is_deleted).not_active.visited_again
      get_localization_keys
    end

    def find_localization
      localization_key = Lit::LocalizationKey.find_by!(localization_key: params[:key])
      locale = Lit::Locale.find_by!(locale: params[:locale])
      localization = localization_key.localizations.find_by(locale_id: locale)
      render json: { path: localization_key_localization_path(localization_key, localization) }
    end

    def starred
      @scope = @scope.where(is_starred: true)

      if defined?(Kaminari) && @scope.respond_to?(Kaminari.config.page_method_name)
        @scope = @scope.send(Kaminari.config.page_method_name, params[:page])
      end
      @scope = @scope.paginate(page: params[:page]) if defined?(WillPaginate) && @scope.respond_to?(:paginate)
      get_localization_keys
      render action: :index
    end

    def star
      @localization_key.toggle :is_starred
      @localization_key.save
      respond_to :js
    end

    def change_completed
      @localization_key.change_all_completed
      respond_to :js
    end

    def restore_deleted
      @localization_key.restore
      respond_to :js
    end

    def destroy
      @localization_key.soft_destroy
      respond_to :js
    end

    def batch_touch
      get_localization_keys
      localization_key_ids = @scope.distinct(false).pluck(:id)
      if localization_key_ids.any?
        @scope.distinct(false).update_all updated_at: Time.current
        Localization.where(localization_key_id: localization_key_ids).update_all updated_at: Time.current
      end
      respond_to :js
    end

    private

    def find_localization_key
      @localization_key = LocalizationKey.find params[:id].to_i
    end

    def find_localization_scope
      @search_options = params.respond_to?(:permit) ? params.permit(*valid_keys) : params.slice(*valid_keys)
      @scope = LocalizationKey.distinct.active.preload(localizations: :locale).search(@search_options)
    end

    def get_localization_keys
      key_parts = @search_options[:key_prefix].to_s.split('.').length
      @prefixes =
        @scope.reorder(nil).distinct.pluck(:localization_key).map do |lk|
          lk.split('.').shift(key_parts + 1).join('.')
        end.uniq.sort
      if @search_options[:key_prefix].present?
        parts = @search_options[:key_prefix].split('.')
        @parent_prefix = parts[0, parts.length - 1].join('.')
      end
      if defined?(Kaminari) and @scope.respond_to?(Kaminari.config.page_method_name)
        @localization_keys = @scope.send(Kaminari.config.page_method_name, params[:page])
      elsif defined?(WillPaginate) and @scope.respond_to?(:paginate)
        @localization_keys = @scope.paginate(page: params[:page])
      else
        @localization_keys = @scope
      end
    end

    def valid_keys
      %w[key key_prefix order]
    end

    def grouped_localizations
      @_grouped_localizations ||=
        begin
          {}.tap do |hash|
            @localization_keys.each do |lk|
              hash[lk] = {}
              lk.localizations.each { |l| hash[lk][l.locale.locale.to_sym] = l }
            end
          end
        end
    end

    def localization_for(locale, localization_key)
      @_localization_for ||= {}
      key = [locale, localization_key]
      ret = @_localization_for[key]
      binding.pry if localization_key == 'scopes.string'
      if ret == false
        nil
      elsif ret.nil?
        ret = grouped_localizations[localization_key][locale]
        unless ret
          ::Rails.logger.info "******** REFRESHING the key"
          Lit.init.cache.refresh_key("#{locale}.#{localization_key.localization_key}")
          ::Rails.logger.info "******** FETCHING the key"
          ret = localization_key.localizations.where(locale_id: Lit.init.cache.find_locale(locale).id).first
        end
        @_localization_for[key] = ret ? ret : false
      else
        ret
      end
    end
    helper_method :localization_for

    def versions?(localization)
      @_versions ||=
        begin
          ids = grouped_localizations.values.map(&:values).flatten.map(&:id)
          Lit::Localization
            .active
            .where(id: ids)
            .joins(:versions)
            .group("#{Lit::Localization.quoted_table_name}.id")
            .count
        end
      @_versions[localization.id].to_i > 0
    end
    helper_method :versions?
  end
end
