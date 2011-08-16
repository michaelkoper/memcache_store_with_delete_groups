module ActiveSupport
  module Cache
    class MemCacheStore
 
      module Common
        KEY = 'all_keys'
      end
  
      # Original method from the memcached store.
      # Only difference is that we modify the key so we support Arrays
      def read(key, options = nil)
        key = key.join(':') if key.is_a?(Array)
        super
        @data.get(key, raw?(options))
      rescue MemCache::MemCacheError => e
        logger.error("MemCacheError (#{e}): #{e.message}")
        nil
      end
  
      # Fetching the entry from memcached
      # For some reason sometimes the classes are undefined
      #   First rescue: trying to constantize the class and try again.
      #   Second rescue, reload all the models
      #   Else raise the exception
      def fetch(key, options = {})
        retries = 2 
        begin
          super
        rescue ArgumentError, NameError => exc         
          if retries == 2
            if exc.message.match /undefined class\/module (.+)$/
              $1.constantize
            end
            retries -= 1
            retry          
          elsif retries == 1
            retries -= 1
            preload_models
            retry
          else 
            raise exc
          end
        end
      end
  
      # Puts the key in the all_keys if it not included and if options delete_type = true.
      # Doing the original write method with _write
      def write(keys, value, options = {})
        # Symbolize all the keys in options
        options.symbolize_keys!
        # We store the keys as strings
        if keys.is_a?(Symbol) || (keys.is_a?(Array) && keys.length == 1)
          key_name = keys.to_s
        end
        # super just logs to logger
        super
        # Add the keys we want to be able to delete with delete_type
        if options[:delete_type]
          raise "delete_type only possible with an array key and the array needs to be bigger than 1" if !keys.is_a?(Array) && keys.length >= 1
          # add the key to the key list
          update_key_list(keys)
          key_chain = generate_key(keys.first, keys[1..-1].join('.'))
        else
          key_chain = keys
        end
        # Do the original write to memcached
        _write(key_chain, value, options)
      end
  
      # Deletes the entries with the specific type from memcached
      def delete_type(type, options = nil)
        # Typecast to Symbol when type is a String
        type = type.to_sym unless type.is_a?(Symbol)
        # Get all the keys from memcached
        key_list = get_key_list
        # Get only the keys for this type
        keys = key_list[type]
        # If the keys are present, delete the key from the key list and delete keys in memcached
        if !keys.blank?
          keys.each do |key|
            # Delete the key from memcached
            delete(generate_key(type,key))
          end
          # Delete the key from the keylist and write the updated key to memcached
          key_list.delete(type)
          _write(Common::KEY, key_list)
        end
      end

      private
  
      # Add a key to the key_list
      def update_key_list(keys)
        key_list = get_key_list
        type = keys.first.to_sym
        key_list[type] = key_list[type] || Set.new
        key_chain = keys[1..-1].join('.')
        unless key_list[type].include?(key_chain)
          key_list[type].add key_chain
          _write(Common::KEY, key_list)
        end
      end
  
      # Gets the keys from memcached
      def get_key_list
        read(Common::KEY) || Hash.new
      end
  
      def generate_key(type,key_chain)
        "#{type}:#{key_chain}"
      end
  
      # This is the original write method of the MemCacheStore
      def _write(key, value, options = nil)
        method = options && options[:unless_exist] ? :add : :set
        response = @data.send(method, key, value, expires_in(options), raw?(options))
        return true if response.nil?
        response == Response::STORED
      rescue MemCache::MemCacheError => e
        logger.error("MemCacheError (#{e}): #{e.message}")
        false
      end
  
      # There are errors sometimes like: undefined class module ClassName.
      # With this method we re-load every model
      def preload_models     
        ActiveRecord::Base.connection.tables.each do |model|       
          begin       
            "#{model.classify}".constantize 
          rescue Exception       
          end     
        end       
      end
    end
  end
end