require "icalendar"
require "haml"
require "sinatra"
require "rest-client"
require "time"
require "date"
require "active_support"

class Available
  PRIO_ROOMS = [
    "HA1",
    "HA2",
    "HA3",
    "HA4",
    "HB1",
    "HB2",
    "HB3",
    "HB4",
    "HC1",
    "HC2",
    "HC3",
    "HC4"
  ].reverse

  def calculate
    rooms = {}

    PRIO_ROOMS.each do |room|
      rooms[room] = []
    end

    cals.first.events.each do |event|
      next if event.dtend.to_time < Time.now or not event.dtstart.today?
      rooms[event.location.upcase] ||= []

      if Time.now.between?(event.dtstart.to_time, event.dtend.to_time)
        start_time = Time.now
      else
        start_time = event.dtstart.to_time
      end

      rooms[event.location.upcase] << [start_time, event.dtend.to_time]
    end

    candidates = []
    PRIO_ROOMS.each do |room|
      if rooms[room].empty?
        candidates << [room, []]
      end
    end

    rooms.each_pair do |room, times|
      next if PRIO_ROOMS.include?(room)
      if times.empty?
        candidates << [room, []]
      end
    end

    candidates += rooms.sort_by{ |room, times| times.count }

    return candidates.uniq
  end

  private


  def cals
    Icalendar.parse(RestClient.get("https://se.timeedit.net/web/chalmers/db1/public/ri663Q18Y66Z55Q5Y169X465y5Z654Y613Y7341Q517116XX4655636355111XY63415652X3Y5Y616X1347156X5165145310X16Y56156Y5443136X563Y5481Y4133056X15Y15X5363X66552031Y10Y346XX558196384Y515450X85616064058683X731YY5X85458483319Y68553515754655XY1Y17QX.ics"))
  end
end

set :haml, :format => :html5

get "/:id?" do
  rooms = Available.new.calculate
  @room, @spans = rooms[params[:id].to_i || 0]
  @max_rooms = rooms.count
  haml :index
end