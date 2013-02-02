module Pod
  class Sandbox

    # Resolves the file patterns of a specification against its root directory,
    # taking into account any exclude pattern and the default extensions to use
    # for directories.
    #
    class FileAccessor

      HEADER_EXTENSIONS = Xcodeproj::Constants::HEADER_FILES_EXTENSIONS

      # @return [Sandbox::PathList] the directory where the source of the Pod
      #         is located.
      #
      attr_reader :path_list

      # @return [Specification::Consumer] the consumer of the specification for
      #         which the file patterns should be resolved.
      #
      attr_reader :spec_consumer

      # @param [Sandbox::PathList] path_list @see path_list
      # @param [Specification::Consumer] spec_consumer @see spec_consumer
      #
      def initialize(path_list, spec_consumer)
        @path_list = path_list
        @spec_consumer = spec_consumer

        unless @spec_consumer
          raise Informative, "Attempt to initialize File Accessor without a specification consumer."
        end
      end

      # @return [Specification] the specification.
      #
      def spec
        spec_consumer.spec
      end

      # @return [Specification] the platform used to consume the specification.
      #
      def platform
        spec_consumer.platform
      end

      # @return [String] A string suitable for debugging.
      #
      def inspect
        "<#{self.class} spec=#{spec.name} platform=#{spec_consumer.platform} root=#{path_list.root}>"
      end

      #-----------------------------------------------------------------------#

      public

      # @!group Paths

      # @return [Array<Pathname>] the source files of the specification.
      #
      def source_files
        paths_for_attribute(:source_files)
      end

      # @return [Array<Pathname>] the headers of the specification.
      #
      def headers
        extensions = HEADER_EXTENSIONS
        source_files.select { |f| extensions.include?(f.extname) }
      end

      # @return [Array<Pathname>] the public headers of the specification.
      #
      def public_headers
        public_headers = paths_for_attribute(:public_header_files)
        if public_headers.nil? || public_headers.empty?
          headers
        else
          public_headers
        end
      end

      # @return [Hash{ Symbol => Array<Pathname> }] the resources of the
      #         specification grouped by destination.
      #
      def resources
        result = {}
        spec_consumer.resources.each do |destination, patterns|
          result[destination] = expanded_paths(patterns)
        end
        result
      end

      # @return [Array<Pathname>] the files of the specification to preserve.
      #
      def preserve_paths
        paths_for_attribute(:preserve_paths)
      end

      # @return [Pathname] The of the prefix header file of the specification.
      #
      def prefix_header
        path_list.root + spec_consumer.prefix_header_file
      end

      # @return [Pathname] The path of the auto-detected README file.
      #
      def readme
        path_list.glob(%w[ readme{*,.*} ]).first
      end

      # @return [Pathname] The path of the license file as indicated in the
      #         specification or auto-detected.
      #
      def license
        specified = path_list.root + spec_consumer.spec.root.license[:file]
        specified || path_list.glob(%w[ licen{c,s}e{*,.*} ]).first
      end

      #-----------------------------------------------------------------------#

      private

      # @!group Private helpers

      # Returns the list of the paths founds in the file system for the
      # attribute with given name. It takes into account any dir pattern and
      # any file excluded in the specification.
      #
      # @param  [Symbol] attribute
      #         the name of the attribute.
      #
      # @return [Array<Pathname>] the paths.
      #
      def paths_for_attribute(attribute)
        file_patterns = spec_consumer.send(attribute)
        dir_pattern = glob_for_attribute(attribute)
        exclude_files = spec_consumer.exclude_files
        expanded_paths(file_patterns, dir_pattern, exclude_files)
      end

      # Returns the pattern to use to glob a directory for an attribute.
      #
      # @param  [Symbol] attribute
      #         the name of the attribute
      #
      # @return [String] the glob pattern.
      #
      # @todo move to the cocoapods-core so it appears in the docs?
      #
      def glob_for_attribute(attrbute)
        globs = {
          :source_files => '*.{h,hpp,hh,m,mm,c,cpp}'.freeze,
          :public_header_files => "*.{#{ HEADER_EXTENSIONS * ',' }}".freeze,
        }
        globs[attrbute]
      end

      # Matches the given patterns to the file present in the root of the path list.
      #
      # @param [Array<String, FileList>] patterns
      #         The patterns to expand.
      #
      # @param  [String] dir_pattern
      #         The pattern to add to directories.
      #
      # @param  [Array<String>] exclude_patterns
      #         The exclude patterns to pass to the PathList.
      #
      # @raise  [Informative] If the pod does not exists.
      #
      # @return [Array<Pathname>] A list of the paths.
      #
      # @todo   Implement case insensitive search
      #
      def expanded_paths(patterns, dir_pattern = nil, exclude_patterns = nil)
        return [] if patterns.empty?

        file_lists = patterns.select { |p| p.is_a?(FileList) }
        glob_patterns = patterns - file_lists

        result = []
        result << path_list.glob(glob_patterns, dir_pattern, exclude_patterns)
        result << file_lists.map do |file_list|
          file_list.prepend_patterns(path_list.root)
          file_list.glob
        end

        unless file_lists.empty?
          UI.warn "[#{spec_consumer.spec.name}] The usage of Rake FileList is deprecated. Use `exclude_files`."
        end

        result.flatten.compact.uniq
      end

      #-----------------------------------------------------------------------#

    end
  end
end

