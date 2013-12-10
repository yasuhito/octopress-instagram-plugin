require 'English'
require 'json'
require 'open-uri'
require 'singleton'

module Jekyll
  # Caches instagram query results.
  class InstagramCache
    include Singleton

    def initialize
      @cache = {}
    end

    def get_by_url(url)
      instagram_id = extract_id_from(url)
      return @cache[instagram_id] if @cache.key?(instagram_id)
      url = 'http://api.instagram.com/oembed?url=' + url
      @cache[instagram_id] = JSON.parse(open(url).read)
    end

    private

    def extract_id_from(url)
      if url =~ %r|http://instagram.com/p/(\w+)/?|
        $1
      else
        fail 'parametor error for instagram tag'
      end
    end
  end

  # Octopress 'instagram' tag.
  class InstagramTag < Liquid::Tag
    def initialize(name, params, token)
      super
      @params = params
    end

    def render(context)
      attributes = %w(class src width height title)
      img = nil

      if @params =~ /(?<class>\S.*\s+)?(?<src>https?:\/\/\S+)(?:\s+(?<width>\d+))?(?:\s+(?<height>\d+))?(?<title>\s+.+)?/i
        img = attributes.reduce({}) do |tmp, attr|
          tmp[attr] = $LAST_MATCH_INFO[attr].strip if $LAST_MATCH_INFO[attr]
          tmp
        end

        original_url = img['src']

        instagram = InstagramCache.instance.get_by_url(img['src'])
        img['src'] = instagram.fetch('url', nil)

        img['width'] = instagram['width']
        img['height'] = instagram['height']

        if img['title']
          img['alt'] = img['title'].gsub!(/"/, '')
        elsif instagram['title']
          img['title'] = instagram['title']
          img['alt']   = instagram['title']
        end
        img['class'].gsub!(/"/, '') if img['class']
      end

      if img
        if img['src'] =~ /mp4$/
          %{<video width='#{instagram["width"]}' height='#{instagram["height"]}' preload='metadata' controls poster=''><source src='#{img['src']}' type='video/mp4; codecs="avc1.42E01E, mp4a.40.2"'></video>}
        else
          "<img #{img.map { |property, value| "#{property}=\"#{value}\"" if value }.join(" ")}>"
        end + %{\n\n<a href="#{original_url}">#{original_url}</a> by <a href="#{instagram['author_url']}">#{instagram['author_name']}</a>}
      else
        ''
      end
    end
  end
end

Liquid::Template.register_tag('instagram', Jekyll::InstagramTag)
