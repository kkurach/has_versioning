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

            elem.send("#{self.class.versioned_foreign_key}=", nil)
            elem.set_new_version
            elem.save_version_on_create
            elem.save_change_update
          end
          options[:before_remove] = [callback_method.to_sym] +
                                    Array(options[:before_remove])
          options.delete(:versioned)
        end

        def update_before_delete_has_many_through(association_id, options)
          callback_method = "before_remove_#{association_id}"
        end

        def has_one(association_id, options={})
          #update_before_delete_hasmany_hasone(association_id, options)
          super
        end

        def has_many(association_id, options={}, &extension)

          if options[:versioned]
            if options[:through]
              update_before_delete_has_many_through(association_id, options)
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
      end

      module InstanceMethods

        def remove_quotes(str)
          while(str.size >= 2) do
            first = str.slice(0,1)
            last = str.slice(-1,1)

            if first == "\"" and last == "\""
              str = str[1..-2]
            elsif first == "("
              str = str[1..-1]
            elsif last == ")"
              str = str[0..-2]
            else
              break
            end

          end
          return str
        end

        # if str is a table name in the database, table_to_class returns
        # corresponding class. otherwise returns nil
        def table_to_class(str)
          str = remove_quotes(str)
          all_tables = ActiveRecord::Base.connection.tables
          if all_tables.include?(str)
            str = str.classify
            if str =~ /\w*Version/
              str = "ActiveRecord::Acts::Svn::" + str
            end
            return str.constantize
          end
          return nil
        end

        def rewrite_query(str)  # TODO make sure it works with inheritance
          vec = str.split(' ')

          used_classes = Set.new

          (0..vec.size-1).each do |i|
              has_dot = vec[i].include?('.')
              table_name = has_dot ? vec[i].split('.')[0] : vec[i]
              table_class = table_to_class(table_name)

              next unless table_class
              #puts "i = #{i} table_name = #{table_name} class = #{table_class.to_s}"

              used_classes << table_class

              if has_dot
                part = vec[i].split('.')
                #puts "SUB #{remove_quotes(part[0])} / #{table_class.versioned_table_name} "
                part[0].sub!(remove_quotes(part[0]), table_class.versioned_table_name)

                p = remove_quotes(part[1])
                p = table_class.versioned_foreign_key if p == table_class.primary_key

                #puts "SUB #{remove_quotes(part[1])} / #{p} "
                part[1].sub!(remove_quotes(part[1]), p)
                vec[i] = part.join('.')
              else
                puts "SUB #{remove_quotes(vec[i])} / #{table_class.versioned_table_name}"
                vec[i].sub!(remove_quotes(vec[i]), table_class.versioned_table_name)
              end
          end

          return [vec.join(' ') , used_classes]
        end

        # this functions takes a association has_many :through, then find
        # all tables on a path, generates SQL join code on versioned tables
        # (using function 'rewrite_query') and then adds join conditions for
        # cl number
        #
        def generate_query(hmt)
          arr = []

          while hmt.options[:through] do #TODO check if all relations are versioned
            arr << hmt.source_reflection.name
            hmt = self.class.reflect_on_association(hmt.options[:through])
          end

          arr << hmt.name
          arr.reverse!
          hash = arr[0..-3].reverse.inject({arr[-2]=>arr[-1]}) do |ele, obj|
            obj = {obj => ele}
          end

          p hash

          str =  self.class.join_map_to_sql( hash )

          new_query, used_classes = rewrite_query(str)
          p new_query
          p used_classes

          conditions = ""
          first = true
          used_classes.each do |clas|
            table = clas.versioned_table_name
            conditions += " AND " unless first
            conditions +=  " #{table}.cl_create <= #{@cl_num} AND #{table}.cl_destroy > #{@cl_num} "
            first = false
          end

          return [new_query, conditions]
        end
      end # InstanceMethods
    end # HasVersioning
end # ActiveRecord


ActiveRecord::Base.send(:include, ActiveRecord::HasVersioning)
