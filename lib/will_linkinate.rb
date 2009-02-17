#$:.unshift(File.dirname(__FILE__)) unless
#  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

module WillLinkinate
# USAGE:
# iterates over a AssociationCollection or Array, using conventional syntax. will_linkinate

# CAVEATS:
# assumes restful architecture for default pathnames. You should always pass :more => false ( or :path_to_more => '/path') and a full block if this is not the case.


# TODO
#  1.) Get a second opinion as to the general applicability vs. the speed
#  2.) repackaged as array.link_to(options) do; end   (???) 
#  .
#  .
#  .
#  803.) perhaps form.link_to(@post.comments, options) to make a restful toggle system that operates within a transaction on @post save.

class ActiveRecord::Associations::AssociationCollection
  def linkinate(options = {}, &block)
    self.extend(ActionView::Helpers::UrlHelper)    
    shallow_url = ActionView::Helpers::UrlHelper.shallow_url(self.proxy_owner)
    options.reverse_merge!(:path_to_more=>"#{shallow_url}/#{class_name.underscore.pluralize}") # MYTODO de-cluge this if I can include polymorphic_url, somehow.
    ActionView::Helpers::UrlHelper.linkinate(options.reverse_merge(:collection => self), &block)
  end
end

module ActiveSupport::CoreExtensions::Array::Conversions 
  def linkinate(options = {}, &block)
    self.extend(ActionView::Helpers::UrlHelper)
    ActionView::Helpers::UrlHelper.linkinate(options.reverse_merge(:collection => self), &block)
  end
end

module ActionView::Helpers::UrlHelper
   def linkinate(options = {})     

    # linkinate(:collection=>@array, :limit=>2) => "<a>item</a>, <a>item</a>, and <a>4 more</a>."
    # ideal api is called and included on an array or collection // NOT called by itself.
    # note that I've exposed some module methods. Not the best performance decision, i'm told.

    # initialize
    collection = options.delete(:collection)
    options.reverse_merge!(
        # :collection,                  # required argument. hidden from api when called on array.
        # :object_method                # if you don't supply a method to call on each object, we guess. I call it synesthemethodesia.
        # :first_index and :last_index  # 3 lines of bloat. So sue me.
        # :path_to_more,                # defaults restfully  ("/posts" for post array), or collection proxy owner.
        # :minimum_more                 # true or integer. makes limit more fuzzy (so you never see "and 1 more")
          :linkinate_first => true,     # example items can be non-links. You fascist.
          :limit => 10,                 # no limit? set it nil.
          :to_sentence=>true, :more=>true,
          :empty_message => "None"
        # :empty_path => "/search"
          )
      
      first_index  = (options[:last_index] - options[:limit]) if options[:last_index] 
      first_index =  options[:first_index] 

      linkables           =  collection.slice!((first_index || 0), (options[:limit] || collection.length))
      linkables_remainder =  collection
            
      (linkables = {options[:empty_message] => options[:empty_path]}) if linkables.empty?

      case options[:minimum_more] 
        when NilClass; # skip!
        when true; linkables += linkables_remainder; linkables_remainder = []
        when Integer
          if options[:minimum_more] < linkables_remainder.length
            linkables += linkables_remainder; linkables_remainder = []
          end
      end

      if block_given?
        links = linkables.map {|linkable| yield(linkable) }
      else
        case linkables
        when Hash;      links = linkables.inject({})  {|i,text,link| i.merge!(text=>link); i }
        end
#   ### assume Array ###
        if links
        else
        case linkables.first 
        when NilClass;  links = []
        when String;    links = linkables.inject({}) {|i,text| i.merge!(text=>nil); i }
        when Object    
                          options.reverse_merge!(:path_to_more=>linkables.first.class.to_s.underscore.pluralize)
                        links = linkables.inject({}) do |i,obj| 
                            method = options[:object_method] || any_method_that_works(obj)
                            raise "please pass an :object_method option to be called on your linkable objects (or deactivate linking with :linkinate_first => false)" unless method                              
                          #  i.merge!(obj.send(method) => url_for(obj)) # MYTODO need to trick rails into letting me include url_for
                            i.merge!(obj.send(method) => shallow_url(obj))
                            i
                            end
        end
        end
        links = links.map do |text,path| 
          if path && options[:linkinate_first]
            link_to text, path
          else
            text
          end
        end
        links
      end

# <a>... and X more.</a>
      last_link = ""
      if options[:path_to_more]
        last_link = (link_to "#{linkables_remainder.length} more", options[:path_to_more])
      else
        last_link = "#{linkables_remainder.length} more"
      end
      links << last_link unless (linkables_remainder.length == 0) or !options[:more]
      # fundamentally flawed approach. If a block is called for array objects, should I also pass/call a block for "more" link?

      case options[:to_sentence]
        when Hash; links.to_sentence(options[:to_sentence])
        when true; links.to_sentence
      else
        links.join(options[:delimiter] || ", ")
      end
    end
    
    def shallow_url(obj)
      "/#{obj.class.class_name.underscore.pluralize}/#{obj.id}"
    end
    
    def any_method_that_works(obj)
      for method in ['name','title','public_filename','login','class']
         return method if obj.respond_to? method
      end
    end
    module_function :linkinate, :any_method_that_works, :shallow_url, :link_to
end
end