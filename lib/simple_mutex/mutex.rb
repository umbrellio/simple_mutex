# frozen_string_literal: true

require "securerandom"
require "json"

module SimpleMutex
  class Mutex
    DEFAULT_EXPIRES_IN = 60 * 60 # 1 hour

    ERR_MSGS = {
      unlock: {
        unknown: lambda do |lock_key|
          "something when wrong when deleting lock key <#{lock_key}>."
        end,
        key_not_found: lambda do |lock_key|
          "lock not found for lock key <#{lock_key}>."
        end,
        signature_mismatch: lambda do |lock_key|
          "signature mismatch for lock key <#{lock_key}>."
        end,
      }.freeze,
      lock: {
        basic: lambda do |lock_key|
          "failed to acquire lock <#{lock_key}>."
        end,
      }.freeze,
    }.freeze

    BaseError = Class.new(::StandardError) do
      attr_reader :lock_key

      def initialize(msg, lock_key)
        @lock_key = lock_key
        super(msg)
      end
    end

    LockError   = Class.new(BaseError)
    UnlockError = Class.new(BaseError)

    class << self
      attr_accessor :redis

      def lock(lock_key, **options)
        new(lock_key, **options).lock
      end

      def lock!(lock_key, **options)
        new(lock_key, **options).lock!
      end

      def unlock(lock_key, signature: nil, force: false)
        ::SimpleMutex.redis_check!

        redis = ::SimpleMutex.redis

        redis.watch(lock_key) do
          raw_data = redis.get(lock_key)

          if raw_data && (force || JSON.parse(raw_data)["signature"] == signature)
            redis.multi { |multi| multi.del(lock_key) }.first.positive?
          else
            redis.unwatch
            false
          end
        end
      end

      def unlock!(lock_key, signature: nil, force: false)
        ::SimpleMutex.redis_check!

        redis = ::SimpleMutex.redis

        redis.watch(lock_key) do
          raw_data = redis.get(lock_key)

          begin
            raise_error(UnlockError, :key_not_found, lock_key) unless raw_data

            unless force || JSON.parse(raw_data)["signature"] == signature
              raise_error(UnlockError, :signature_mismatch, lock_key)
            end

            success = redis.multi { |multi| multi.del(lock_key) }.first.positive?

            raise_error(UnlockError, :unknown, lock_key) unless success
          ensure
            redis.unwatch
          end
        end
      end

      def with_lock(lock_key, **options, &block)
        new(lock_key, **options).with_lock(&block)
      end

      def raise_error(error_class, msg_template, lock_key)
        template_base = error_class.name.split("::").last.gsub("Error", "").downcase.to_sym
        error_msg     = ERR_MSGS[template_base][msg_template].call(lock_key)

        raise(error_class.new(error_msg, lock_key))
      end
    end

    attr_reader :lock_key, :expires_in, :signature, :payload

    def initialize(lock_key,
                   expires_in: DEFAULT_EXPIRES_IN,
                   signature:  SecureRandom.uuid,
                   payload:    nil)
      ::SimpleMutex.redis_check!

      self.lock_key    = lock_key
      self.expires_in  = expires_in.to_i
      self.signature   = signature
      self.payload     = payload
    end

    def lock
      !!redis.set(lock_key, generate_data, nx: true, ex: expires_in)
    end

    def unlock(force: false)
      self.class.unlock(lock_key, signature: signature, force: force)
    end

    def with_lock
      lock!

      begin
        yield
      ensure
        unlock
      end
    end

    def locked?
      !redis.get(lock_key).nil?
    end

    def lock!
      lock or raise_error(LockError, :basic)
    end

    def unlock!(force: false)
      self.class.unlock!(lock_key, signature: signature, force: force)
    end

    private

    attr_writer :lock_key, :expires_in, :signature, :payload

    def generate_data
      JSON.generate(
        "signature"  => signature,
        "created_at" => Time.now.to_s,
        "payload"    => payload,
      )
    end

    def redis
      ::SimpleMutex.redis
    end

    def raise_error(error_class, msg_template)
      self.class.raise_error(error_class, msg_template, lock_key)
    end
  end
end
