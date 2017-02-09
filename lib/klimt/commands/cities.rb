require 'byebug'
require 'klimt/rendering'

module Klimt
  module Commands
    class Cities < Thor
      include Rendering

      desc 'list', 'List all currently geocoded cities from S3'
      method_option :featured, desc: 'Restrict to just "featured" cities', type: :boolean
      method_option :short, desc: 'Show compact output', type: :boolean
      def list
        uri = "http://artsy-geodata.s3-website-us-east-1.amazonaws.com/partner-cities/#{'featured-' if options[:featured]}cities.json"
        response = Typhoeus.get(uri)
        jq_filter = options[:short] ? '.[] | { full_name, coords }' : '.'
        jq_options =  options[:short] ? '-c' : ''
        render response.body, jq_filter: jq_filter, jq_options: jq_options
      end
    end
  end
end
