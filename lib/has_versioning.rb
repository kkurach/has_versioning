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


# ActsAsSvn
module ActiveRecord  # :nodoc:
  module HasVersioning  # :nodoc:
    
    # this value should be bigger than any changelist id
    MAX_CL_NUMBER = 2000000000  # FIXME

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      # Adds version control system to object, and selected
      # relations.
      #
      #
      # Args:
      # - versioned_table_name: Name of the table to store versions
      # - real_id: column to link the versioned class to normal
      # - cl_create_column: name of the column in versioned table, which
      #                     stores information about changelist number,
      #                     on which given object version was created
      # - cl_destroy_column: name of the column in versioned table, which
      #                      stores information about changelist number,
      #                      on which given object version was destroyed
      #
      def has_versioning(options={})
        return if self.included_modules.include?(
            ActiveRecord::HasVersioning::InstanceMethods)

        include ActiveRecord::HasVersioning::InstanceMethods

        class_eval do
          cattr_accessor :versioned_class_name,
                         :real_id,
                         :version_column,
                         :versioned_table_name,
                         :cl_create_column,
                         :cl_destroy_column

          attr_accessor  :cl_num
        end

        # TODO(kkurach): allow user to use his own class_name
        # I can't do it now, because function 'table_to_class' which returns
        # class name from table name name('associations_svn.rb') has been
        # written pathologically, and assumes that user has only standard
        # table names for all versioned classes
        self.versioned_class_name = "#{self.to_s.demodulize}"

        desc_class = class_name_of_active_record_descendant(self).
            demodulize.underscore

        self.versioned_table_name = options[:table_name] ||
            "#{table_name_prefix}#{desc_class}_versions#{table_name_suffix}"
        
        # FIXME(kkurach): why it blows up when I change true_id -> real_id ??!
        self.real_id = options[:real_id] || 'true_id'  

        # TODO(kkurach): allow user to use his own version_column name
        self.version_column = 'version'


        self.cl_create_column = options[:cl_create_column] ||
                                'cl_create'

        self.cl_destroy_column = options[:cl_destroy_column] ||
                                 'cl_destroy'
        class_eval do
          before_save :set_new_version

          after_create :save_version_on_create_or_update
          after_update :save_version

          after_create :save_change_create
          before_destroy :save_change_destroy
          after_update :save_change_update

        end  # class eval
        
      end

      # Return an array of names that are saved in the versioned table
      #
      def versioned_column_names
        self.column_names - self.non_versioned_fields
      end

      # Returns an array of fields that are NOT saved in the versioned table
      #
      def non_versioned_fields
        [self.primary_key,
         cl_create_column,
         cl_destroy_column,
         'lock_version']
      end

      # returns array of columns which have to be in versioned_table
      # this function is used for creating migration in
      # 'create_versioned_table'
      #
      # Returns:
      # - array of columns which have to be in versioned table
      #
      def versioned_columns
        self.columns.reject { |c| non_versioned_fields.include?(c.name) }
      end

      # Returns versioned class corresponding to given class
      #
      def versioned_class
        self
      end

      def add_column(table_name, attribute_name, type, opts={})
        return if self.columns_hash.has_key?(attribute_name.to_s)
        self.connection.add_column table_name, attribute_name, type, opts
      end
      # Creates a table with versions of given object. This function
      # should be called in migration on each object we want to version.
      #
      #
      # Args:
      # - all valid args for create_table method
      #
      def add_versioning_columns(create_table_options={})
        add_column(table_name, real_id, :integer)
        add_column(table_name, cl_create_column, :integer)
        add_column(table_name, cl_destroy_column, :integer)
        add_column(table_name, version_column, :integer)
        add_column(table_name, :is_versioned_obj, :integer)

        updated_col = nil
        self.versioned_columns.each do |col|
          if !updated_col and %(updated_at updated_on).include?(col.name)
            updated_col = col
          end
        end


        add_column(table_name, :updated_at, :timestamp)
        self.reset_column_information
      end


      # Rake migration task to drop the versioned table
      #
      def delete_versioning_columns
        puts "No way"
        #  FIXME delete_versioning_columns
        # self.connection.drop_table versioned_table_name
      end


      # returns all rows from model's table which are versions.
      # useful for debugging purposes.
      #
      # FIXME:  I think it works only by mistake, because it's merging
      # arguments { :is_versioned_obj = 1 }  (from my scope), and
      # { :is_versioned_obj = 0 }  from  self.find( )  (find is scoped to = 0,
      # as I overrided it in ActiveRecord::Base).  so, I should get
      # "is_versioned_obj = 0"  AND "is_versioned_obj = 1", which is an
      # empty set.
      #
      # Returns:
      # - all rows from model's table which have "is_versioned_obj = 1"
      #
      def find_all_versions
        self.send(:with_scope, :find => { :conditions => { :is_versioned_obj => 1 } }) do
          self.find(:all)
        end
      end
      
      # yet anothet debugging tool
      #
      def dump
        vec1 = self.find(:all)
        vec2 = self.find_all_versions
        vec2 unless vec1
        vec1.concat(vec2).sort { |x,y|  x.id <=> y.id }
      end

      # Convert a join map to a sql query string
      #
      # Args:
      # - joins: An array or hash of associations to be joined (takes the
      #          same format as the :include/:joins argument to find)
      # Returns:
      # - A string containing sql join statements
      #
#      def join_map_to_sql(joins=[])
#        # Convert join_map into sql statements
#        ActiveRecord::Associations::ClassMethods::JoinDependency.new(
#            self, joins, nil).join_associations.map(&:association_join).join
#      end

    end


    module InstanceMethods
      @new_ver_added = false

      # This function is used to tell, which objects are under version
      # constrol. It's used in find_target. Also, it will be used in
      # has_many :through.
      #
      def acts_like_svn?  # TODO(kkurach): change to sth else
        true
      end

      def next_version_number
        current_version_number + 1
      end


      # gives the number of the most recent object version
      #
      #
      # Returns:
      # - 0 if the object wasn't saved yet
      # - highest version number from all versions of given object otherwise
      #
      # Throws:
      # - runtime error if object wasn't found
      #
      def current_version_number
        return 0 if new_record?

        ret = nil
        self.class.send(:with_scope,  :find => { :conditions => { :is_versioned_obj => 1 } })  do
          ret = self.class.find(:first, :conditions => ["#{cond_for_version}"],
                                      :order => "version desc")
        end

        raise RuntimeError, 'No current version!?' unless ret
        ret = ret.version

        ret
      end

      def previous_version_number
        current_version_number - 1
      end

      # returns string with conditions for
      def cond_for_version
        "is_versioned_obj = 1 and #{self.class.real_id} = #{self.id}"
      end

      # returns all versions of given object
      #
      def versions
        self.class.send(:with_scope,  :find => { :conditions => { :is_versioned_obj => 1 } })  do
          self.class.find(:all, :conditions => ["#{cond_for_version}"])
        end
      end

      # returns version number "num" of given object, or nil
      # if it doesn't exists
      #
      def get_version(num, cond={})
        cond[:is_versioned_obj] = 1
        self.class.send(:with_scope,  :find => { :conditions => cond })  do
          self.class.find(:first, :conditions => ["#{cond_for_version} and version = #{num}"])
        end
      end

      # returns object in the most recent version
      #
      def current_version
        get_version(current_version_number)
      end

      def previous_version
        get_version(previous_version_number)
      end

      # this method is called before save, to check if any of the
      # attributes has changed (in compare to the last version)
      #
      # for now it's only a wrapper for 'changed?'. we can consider
      # adding more logic later (for example: save only after changes to
      # selected subset of fields)
      #
      #
      # Returns:
      # - true if one or more object attributes has changed, false otherwise
      #
      def save_version?  # TODO(kkurach): make it private
        changed?
      end

      # callback after update - it will save version iff there
      # were any changes to the object
      #
      def save_version
        return true if self.is_versioned_obj == 1

        save_version_on_create_or_update if save_version?
      end

      # callback after creating object and after update(if there're changes)
      # it saves object with new attributes to versioned table, with next
      # version number.
      # also, it sets instance variable 'new_ver_added' if new row was saved.
      # this variable is needed by 'save_change' callback
      #
      def save_version_on_create_or_update
        return true if self.is_versioned_obj == 1

        self.send("#{self.class.real_id}=", self.id)

        rev = self.class.versioned_class.new

        # set all attributes
        copy_existing_attributes(rev, self)

        rev.version = send(self.class.version_column)
        rev.send("#{self.class.real_id}=", self.id)
        rev.send("#{self.class.cl_create_column}=", Changelist.current.id)
        rev.send("#{self.class.cl_destroy_column}=", MAX_CL_NUMBER)
        rev.is_versioned_obj = 1

        rev.save!

        @new_ver_added = true
      end

      # in short: new_model = orig_model
      # it copies to new_model only attributes that exists in
      # both new_model and orig_model, and are not versioned
      #
      #
      # Args:
      # - new_model: object which will be modified
      # - orig_model: object from which all values are taken
      #
      def copy_existing_attributes(new_model, orig_model)
        # FIXME(kkurach): dup here is enough?

        orig_model.attribute_names.each do |key|
          next if self.class.non_versioned_fields.include?(key)

      #    if new_model.attribute_names.include?(key)
            new_model.send("#{key}=", orig_model.attributes[key])
      #    end
        end
      end

      # callback before save. it sets the correct value in version_column
      #
      def set_new_version
        return if self.is_versioned_obj == 1
        if (new_record? or save_version?)
            self.is_versioned_obj = 0
            self.send("#{self.class.version_column}=", next_version_number)
        end
      end

      # updates value in 'cl_destroy_column' in row corresponding
      # to previous version of given object
      #
      # TODO(kkurach): change string to symbols, to make it more efficient
      #
      #
      # Args:
      # - operation: string from set { 'create', 'destroy', 'update' }
      #
      def update_old_row(operation)
        return if operation == 'create'
        obj = (operation == 'update' ? previous_version : current_version)
        obj.send("#{cl_destroy_column}=", Changelist.current.id)
        obj.save!
      end

      # this function is called AFTER {create, update} and BEFORE destroy
      # it adds one row to 'changes' table, indicating what has happened
      # to the object (it might have been created, destroyed or updated)
      #
      # this function also updates value in 'cl_destroy_column' in row
      # corresponding to previous version of given object (by calling
      # 'update_old_row' function)
      #
      #
      # Args:
      # - operation: string from set { 'create', 'destroy', 'update' }
      #
      def save_change(operation)
        return if self.is_versioned_obj == 1
        return unless @new_ver_added || operation == 'destroy'

        @new_ver_added = false

        self.update_old_row(operation)

        c = Change.new
        c.changelist_id = Changelist.current.id
        c.class_name = self.versioned_class_name
        c.row_id = self.current_version.id
        c.change_type = operation
        c.save!

        Changelist.after_save_change
      end

      # function described in 'save_change'
      #
      def save_change_create
        save_change('create')
      end

      # function described in 'save_change'
      #
      def save_change_destroy
        save_change('destroy')
      end

      # function described in 'save_change'
      #
      def save_change_update
        save_change('update')
      end

      # returns object with all attributes setted to those from
      # version number 'ver'
      #
      #
      # Args:
      # - ver: version number, must be > 0 and <= current_version_number
      #
      # Returns:
      # - object at given version
      #
      # Throws:
      # - RuntimeError, if there's no object with given version
      #
      def at_version(ver)
        obj = get_version(ver)
        raise RuntimeError, 'Bad version number' unless obj

        obj.to_normal
      end

      # returns object with all attributes setted to those from
      # changelist number 'cl'. it allows also to query relations.
      # it throws a runtime error if the object
      # didn't exist at given cl number
      #
      # example:
      #
      # we have a class Car and User (who has many :cars),and make query
      # as follow:
      # user.at_changelist(5).name  -->  name of user at changelist 5
      # user.at_changelist(5).cars  -->  cars of the user at changelist 5
      #
      # it works like a rails proxy, so following calls are ok:
      #
      # user.at_changelist(5).cars.count
      # user.at_changelist(5).cars.find(:all, :conditions => { :size => 4 })
      #
      #
      # Args:
      # - cl: number of changelist
      #
      # Returns:
      # - object with all parameters setted to values from changelist cl.
      #   all versioned relations will return only objects present at cl.
      #
      # Throws:
      # - RuntimeError, when object didn't exist at changelist 'cl'
      #
      def at_changelist(cl)
        obj = nil

        scope_cond = { :find => { :conditions => { :is_versioned_obj => 1 } } }
        find_cond = ["#{cond_for_version} and cl_create <= ? and
                      cl_destroy > ?",cl, cl]

        self.class.send(:with_scope,  scope_cond)  do
          obj = self.class.find(:first, :conditions => find_cond)
        end
        raise RuntimeError, "This object didn't exist at cl #{cl}" unless obj

        obj.cl_num = cl
        obj.to_normal
      end

      # obj.revert_to_version(ver) is equivalent to
      # obj = obj.at_version(ver)
      #
      def revert_to_version(ver)
        obj = self.at_version(ver)
        copy_existing_attributes(self, obj)  # as obj.class == self.class
        self.save!
      end

      # obj.revert_to_changelist(cl) is equivalent to
      # obj = obj.at_changelist(cl)
      #
      def revert_to_changelist(cl)
        obj = self.at_changelist(cl)
        copy_existing_attributes(self, obj)  # as obj.class == self.class
        self.save!
      end

      # given versioned object and normal object, it sets
      # all attributes of normal object
      #
      #
      # Args:
      # - ver_obj: versioned object. will NOT be modified
      # - norm_obj: normal object. will BE modified.
      #
      # Returns:
      # - normal object, with all attributes setted
      #
      def versioned_to_normal(ver_obj, norm_obj)

        norm_obj = ver_obj

        norm_obj.is_versioned_obj = 0

        # set all non-versioned attributes (except of primary key)
        # to nil (canonical representation of an object)
        self.class.non_versioned_fields.each do |key|
          next if key == norm_obj.class.primary_key
          if norm_obj.attribute_names.include?(key)
            norm_obj.send("#{key}=", nil)
          end
        end

        # set version column
        val = ver_obj.send(norm_obj.class.version_column)
        norm_obj.send("#{norm_obj.class.version_column}=", val)

        # set primary key
        primary_key = norm_obj.class.primary_key
        key_to_norm = norm_obj.real_id
        if ver_obj.attributes[key_to_norm]  # don't set nil
          norm_obj.send("#{primary_key}=", ver_obj.attributes[key_to_norm])
        end

        norm_obj.freeze
        norm_obj
      end

      # to_normal may be called on normal object or on versioned
      # object. in both cases it will return normal object
      #
      def to_normal
        ret = self.dup
        ret.is_versioned_obj = 0
        versioned_to_normal(self, ret)
      end

    end  # InstanceMethods

  end  # HasVersioning
end  # ActiveRecord

## work-around of rails bug
# (see:https://rails.lighthouseapp.com/projects/8994/tickets/
# 2577-when-using-activerecordassociations-outside-of-rails-a-nameerror-is-thrown)
ActiveRecord::ActiveRecordError
#### end of work-around

module ActiveRecord::Associations

  class AssociationProxy

    # scope_to_cl is a wrapper for several Rails association functions.
    # first, it checks if object which is calling functions is using the plugin.
    # if not - original function is returned.
    # if yes, there are 2 cases:
    #
    # 1. object is calling function without at_changelist
    # in this case  @cl_num is set to nil.  query will be made
    # for objects which currently exist (so, for those which have
    # cl_destroy = MAX_CL_NUMBER)
    #
    # 2. object is calling function, with at_changelist.
    # in this case, query will be made for object which existed
    # at changelist @cl_num
    #
    # Args:
    # - block:  function which should be scoped (from rails core)
    #
    # Returns:
    # - value returned by scoped function
    #
    def scope_to_cl(&block)
      return yield unless @owner.acts_like?('svn')

      max_cl = ActiveRecord::HasVersioning::MAX_CL_NUMBER
      cl_num = @owner.cl_num || max_cl - 1

      cond = { :is_versioned_obj => 1,
               :cl_create => 0..cl_num,
               :cl_destroy => (cl_num+1)..max_cl }

      with_scope({ :find => { :conditions => cond }} ) do  # TODO: why nested scope doesn't work?
        yield
      end
    end

    # process_output deals with output returned by find_target.
    # in case that object isn't under version control, it just
    # do nothing (because in this case also original find_target
    # wasn't changed). otherwise we need to do mapping
    # versioned_object --> normal_object
    #
    # if object is under version control, but @cl_num is not setted
    # it returns current object, else object at changelist @cl_num
    #
    # Args:
    # - elem: object returned by find_target
    #
    # Returns:
    # - elem if @owner not under version control
    # - elem changed to normal obj if @owner under version control
    #   and @cl_num is not setted
    # - elem at changelist @cl_num, if @cl_num setted
    #
    def process_output(elem)
      return elem unless @owner.acts_like?('svn')
      return nil unless elem
      elem.to_normal
      return @owner.cl_num ? elem.at_changelist(@owner.cl_num) : elem
    end

  end

  class BelongsToAssociation < AssociationProxy #:nodoc:

    alias_method :find_target_orig, :find_target
    def find_target
      
      # I'm changing  id --> obj_id in query to klass
      old_val = @reflection.options[:primary_key]
      @reflection.options[:primary_key] = @reflection.klass.real_id
      vec = scope_to_cl { find_target_orig }
      @reflection.options[:primary_key] = old_val

      process_output(vec)
    end
  end

  class HasOneAssociation < BelongsToAssociation #:nodoc:
    alias_method :find_target_orig, :find_target

    # find_target for has_one..  it returns unfrozen target
    # (I'm calling obj.dup here), because sometimes it'll be modified
    # (e.g. foreign_key --> NULL on delete)
    #
    def find_target
      vec = scope_to_cl { find_target_orig }
      obj = process_output(vec)
      obj ? obj.dup : obj
    end
  end
  
  class HasManyThroughAssociation < HasManyAssociation
    alias_method :find_target_orig, :find_target

    def find_target
      return find_target_orig unless @owner.acts_like?('svn')

      max_cl = ActiveRecord::HasVersioning::MAX_CL_NUMBER
      cl_num = @owner.cl_num || max_cl - 1
      
      tab1 = @reflection.through_reflection.quoted_table_name
      tab2 = @reflection.quoted_table_name

      cond = [" #{tab1}.is_versioned_obj = 1 and #{tab1}.cl_create <= #{cl_num} and
                #{tab1}.cl_destroy > #{cl_num} and #{tab2}.is_versioned_obj = 1 and
                #{tab2}.cl_create <= #{cl_num} and #{tab2}.cl_destroy > #{cl_num} " ]
      
      vec = nil
      with_scope({ :find => { :conditions => cond }} ) do  # TODO: why nested scope doesn't work?
        vec = find_target_orig
      end
      vec.map { |elem| process_output(elem) }
    end
    
#    alias_method :construct_joins_orig, :construct_joins
    # scary stuff from ActiveRecord...
    #
    def construct_joins(custom_joins = nil)

      polymorphic_join = nil
      if @reflection.source_reflection.macro == :belongs_to
        reflection_primary_key = @reflection.klass.primary_key
        source_primary_key     = @reflection.source_reflection.primary_key_name
        if @reflection.options[:source_type]
          polymorphic_join = "AND %s.%s = %s" % [
            @reflection.through_reflection.quoted_table_name, "#{@reflection.source_reflection.options[:foreign_type]}",
            @owner.class.quote_value(@reflection.options[:source_type])
          ]
        end
      else
        reflection_primary_key = @reflection.source_reflection.primary_key_name
        source_primary_key     = @reflection.through_reflection.klass.primary_key
        if @reflection.source_reflection.options[:as]
          polymorphic_join = "AND %s.%s = %s" % [
            @reflection.quoted_table_name, "#{@reflection.source_reflection.options[:as]}_type",
            @owner.class.quote_value(@reflection.through_reflection.klass.name)
          ]
        end
      end

      ret = "INNER JOIN %s ON %s.%s = %s.%s %s #{@reflection.options[:joins]} #{custom_joins}" % [
        @reflection.through_reflection.quoted_table_name,
        @reflection.quoted_table_name, @owner.class.real_id, #reflection_primary_key,  FIXME
        @reflection.through_reflection.quoted_table_name, source_primary_key,
        polymorphic_join
      ]

      #puts "ret = #{ret}"
      ret
    end
  end

  class  AssociationCollection < AssociationProxy

    alias_method :count_orig, :count
    def count(*args)
      scope_to_cl { count_orig(*args) }
    end

    alias_method :sum_orig, :sum
    def sum(*args)
      scope_to_cl { sum_orig(*args) }
    end

    alias_method :size_orig, :size
    def size
      scope_to_cl { size_orig }
    end

    alias_method :find_orig, :find
    def find(*args)
      scope_to_cl { find_orig(*args) }
    end

    # FIXME:  nested with_scope doesn't work.
    # FIXME:  I believe it's a Rails bug:
    # https://rails.lighthouseapp.com/projects/8994-ruby-on-rails/tickets
    # /3079-with_scope-merges-find-conditions-incorrectly
    #
    # what's more strange, this approach works:
    #  cond = { :is_versioned_obj => 1,
    #           :cl_create => 0..cl_num,
    #           :cl_destroy => (cl_num+1)..max_cl }
    #
    # with_scope( :find => { :conditions => cond } )  {  find(:all) }
    #
    #
    # and the one below (which should be isomorphic) doesn't work:
    #
    #  cond1 = { :is_versioned_obj => 1 }
    #  cond2 = { :cl_create => 0..cl_num, :cl_destroy => (cl_num+1)..max_cl }
    #
    #  with_scope( :find => { :conditions => cond1 }) do
    #    with_scope( :find => { :conditions => cond2}) {  find(:all) }
    # end
    #
    #
    alias_method :find_target_orig, :find_target
    def find_target
      vec = scope_to_cl { find_target_orig }
      vec.map { |elem| process_output(elem) }
    end

    private

  end
end

module ActiveRecord
  class Base

    # "dup" it's taken from:
    # https://rails.lighthouseapp.com/projects/8994/tickets/2859-patch-added-
    # arbdup-method-for-duplicationg-object-without-frozen-attributes
    #
    # I added it here, because otherwise it's impossible to unfreeze object
    # using dup  (in ActiveRecord:Base).
    #
    # TODO(kkurach):
    # once this fix is merged to Rails source, we can get rid of this method
    #
    def dup
      obj = super
      obj.instance_variable_set('@attributes', instance_variable_get('@attributes').dup)
      obj
    end

    class << self
      alias_method :find_orig, :find

      # on default, query non versioned objects.  So,  Cars.count should
      # count only "real" objects with is_versioned_obj = 0.
      # but when someone calls  i.e. user.at_changelist.cars.count,  this
      # is_versioned_obj = 0 will be overriden by is_versioned_obj = 1
      # (check out add_conditions! function )
      #
      def find(*args)
        return find_orig(*args) unless self.new.acts_like?('svn')
        with_scope(:find => { :conditions => { :is_versioned_obj => 0 } }) do
          find_orig(*args)
        end
      end

      # DIRRRRTYYYY hack.....give always priority
      # to versioned objects.
      #
      def add_conditions!(sql, conditions, scope = :auto)
        scope = scope(:find) if :auto == scope

        # my hack begins..
        if scope
          txt = scope[:conditions]
          if txt.include? "cl_create"
            txt.gsub!("\"is_versioned_obj\" = 0", "\"is_versioned_obj\" = 1")
          end
          scope[:conditions] = txt
        end
        # my hack ends..

        conditions = [conditions]
        conditions << scope[:conditions] if scope
        conditions << type_condition if finder_needs_type_condition?
        merged_conditions = merge_conditions(*conditions)
        sql << "WHERE #{merged_conditions} " unless merged_conditions.blank?

        sql
      end

    end
  end
end

module ActiveRecord
  module Calculations
    module ClassMethods
      alias_method :orig_calculate, :calculate

      # scope calculate to non-versioned objects (like find in AR::Base)
      # count, sum, avg, etc. are wrappers for calculate, so it should make
      # all those functions work
      #
      def calculate(operation, column_name, options = {})
        return orig_calculate(operation, column_name, options) unless self.new.acts_like?('svn')
        with_scope(:find => { :conditions => { :is_versioned_obj => 0 } }) do
          orig_calculate(operation, column_name, options)
        end
      end
    end
  end
end


ActiveRecord::Base.send(:include, ActiveRecord::HasVersioning)
