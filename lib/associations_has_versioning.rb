# Copyright 2009 Google Inc.
# Original author: Karol Kurach <kkurach (at) gmail (dot) com>
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module ActiveRecord
    module HasVersioning

      module ClassMethods

        def update_before_delete_hasmany_hasone(association_id, options)
          callback_method = "before_remove_#{association_id}"

          define_method(callback_method) do |elem|
            # don't do anything when elem is not in collection
            # so, when it's previous version doesn't exist
            return if elem.previous_version_number.zero?

            foreign_key = options[:foreign_key] ||
                          "#{self.class.to_s.foreign_key}"

            elem.send("#{foreign_key}=", nil)
            elem.set_new_version
            elem.save_version_on_create_or_update
            elem.save_change_update
          end
          options[:before_remove] = [callback_method.to_sym] +
                                    Array(options[:before_remove])
          options.delete(:versioned)
        end

        
        def belongs_to(association_id, options={})
          options.delete(:versioned)
          super
        end

        def has_one(association_id, options={})
          if options[:versioned] && options[:through]
            raise RuntimeError, 'versioning not supported for has_one :through'
          end
          options.delete(:versioned)
          super
        end

        def has_many(association_id, options={}, &extension)

          if options[:versioned]
            if options[:through]
              puts "has many :through"
              #raise RuntimeError, 'versioning not supported for has_many :through'
            else
              update_before_delete_hasmany_hasone(association_id, options)
            end
            options.delete(:versioned)
          end

          super
        end

        def has_and_belongs_to_many(association_id, options={}, &extension)
          if options[:versioned]
            raise RuntimeError, 'versioning not supported for habtm'
          end
          super
        end

      end # ClassMethods

    end # HasVersioning
end # ActiveRecord


ActiveRecord::Base.send(:include, ActiveRecord::HasVersioning)
