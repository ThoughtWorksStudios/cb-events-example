#!/usr/bin/env ruby

require "rubygems"
require "bundler/setup"
require "mingle_events"

class StoryDeliveryStatus

  # Selects only changes to Story cards. This is using a very lightweight heuristic on title
  # because it's much more performant than using CardTypeFilter with a CardData processor
  # (which hits the Mingle server for each card event to retrieve data).
  class StoryTypeFilter < MingleEvents::Processors::Filter
    def match?(event)
      event.card? && event.title.strip.downcase =~ /^story \#[\d]+ /
    end
  end

  # Again, use a lightweight filter instead of the very heavy CustomPropertyFilter to avoid
  # hitting Mingle for every card event
  class ChangedDeliveryStatusFilter < MingleEvents::Processors::Filter
    def self.test(c)
      c[:type].term == "property-change" && c[:property_definition][:name].downcase == "delivery status"
    end

    def match?(event)
      event.card? && event.changes.any? do |c|
        ChangedDeliveryStatusFilter.test(c)
      end
    end
  end

  # print out a human-readable message
  class DeliveryStatusPublisher < MingleEvents::Processors::Processor
    def process(event)
      short_name = event.title.match(/^(story \#[\d]+) /i)[1]
      change = (event.changes.select {|c| ChangedDeliveryStatusFilter.test(c) }).first
      puts %Q{#{short_name} changed #{change[:property_definition][:name].inspect} from #{change[:old_value].inspect} to #{change[:new_value].inspect} on #{event.updated}}
    end
  end

  def self.main(*args)
    raise "You must specify a yaml config file! Try the \"local.yml\" example" if args.size < 1
    file = args.shift
    raise "config file #{file} does not exist!" unless File.exist?(file)
    puts "loading config at: #{file}"
    config = YAML.load(File.read(file))

    mingle_access = MingleEvents::MingleBasicAuthAccess.new(config["base_url"].chomp("/"), config["login"], config["password"])
    project = config["project"]

    # build the processort/filter pipeline through which we feed fetched events
    story_delivery_status = MingleEvents::Processors::Pipeline.new([
      StoryTypeFilter.new,
      MingleEvents::Processors::CategoryFilter.new([MingleEvents::Feed::Category::PROPERTY_CHANGE]),
      ChangedDeliveryStatusFilter.new,
      DeliveryStatusPublisher.new
    ])

    # set up our event fetcher
    event_fetcher = MingleEvents::ProjectEventFetcher.new(project, mingle_access)
    event_fetcher.fetch_latest

    # do it!
    story_delivery_status.process_events(event_fetcher.all_fetched_entries)
  end

end

StoryDeliveryStatus.main(ARGV[0])
