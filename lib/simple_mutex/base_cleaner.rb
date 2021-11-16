# frozen_string_literal: true

module SimpleMutex
  class BaseCleaner
    def unlock
      ::SimpleMutex.redis_check!

      logger&.info(start_msg)

      redis.keys.select do |lock_key|
        redis.watch(lock_key) do
          raw_data = redis.get(lock_key)

          next redis.unwatch if raw_data.nil?

          parsed_data = safe_parse(raw_data)

          next redis.unwatch unless parsed_data&.dig("payload", "type") == type

          entity_id = parsed_data&.dig(*path_to_entity_id)

          next redis.unwatch if entity_id.nil? || active?(entity_id)

          return_value = redis.multi { |multi| multi.del(lock_key) }

          log_iteration(lock_key, raw_data, return_value) unless logger.nil?

          return_value&.first&.positive?
        end
      end

      logger&.info(end_msg)
    end

    private

    def active?(entity_id)
      active_entity_ids.include?(entity_id)
    end

    # @!method type
    # @!method path_to_entity_id
    # @!method get_active_entity_ids

    def safe_parse(raw_data)
      JSON.parse(raw_data)
    rescue JSON::ParserError, TypeError
      nil
    end

    def active_entity_ids
      return @active_entity_ids if defined? @active_entity_ids

      @active_entity_ids = get_active_entity_ids
    end

    def log_iteration(lock_key, raw_data, return_value)
      log_msg = generate_log_msg(lock_key, raw_data, return_value)

      # should not happen, but we encountered this few times long time ago
      unless return_value&.first.is_a?(Integer)
        return logger.error(log_msg)
      end

      return_value&.first&.positive? ? logger.info(log_msg) : logger.warn(log_msg)
    end

    def start_msg
      "START #{self.class.name}"
    end

    def end_msg
      "END #{self.class.name}"
    end

    def generate_log_msg(lock_key, raw_data, return_value)
      "Trying to delete row with key <#{lock_key.inspect}> "\
      "and value <#{raw_data.inspect}>. "\
      "MULTI returned value <#{return_value.inspect}>."
    end

    def redis
      ::SimpleMutex.redis
    end

    def logger
      ::SimpleMutex.logger
    end
  end
end
