require "thread"
require "icalendar"
require "rest-client"
require "time"
require "date"
require "active_support"

class Available
  NOW = -1
  PRIO_ROOMS = ["HC4", "HC3", "HC2", "HC1", "HB4", "HB3", "HB2", "HB1", "HA4", "HA3", "HA2", "HA1", "EA", "EB", "EC", "ED", "EE", "ES51", "ES52", "ES53", "ES61", "3207", "3209", "3211", "3213", "3215", "3217", "4205", "4207", "4215", "5205", "5207", "5209", "5211", "5213", "5215", "5217", "6205", "6207", "6209", "6211", "6213", "6215", "EF", "EL41", "EL43", "EL42", "MA", "MB", "MC", "ML1", "ML11", "ML12", "ML13", "ML14", "ML15", "ML16", "ML2", "ML3", "ML4"]

  IGNORE_ROOMS = [
    "4216",
    "4218",
    "ES62", 
    "ES63"
  ]

  def calculate
    rooms = {}

    PRIO_ROOMS.each do |room|
      rooms[room] = []
    end

    events.each_with_index do |event, index|
      if event.dtend.to_time < Time.now or not event.dtstart.today?
        next debug("Event #{index} is not scheduled today")
      end

      # Some rooms are joined together on one line
      event.location.upcase.split(/,\s*/).each do |found_room|
        if IGNORE_ROOMS.include?(found_room)
          next debug("Ignore room #{found_room}")
        end

        rooms[found_room] ||= []

        if Time.now.between?(event.dtstart.to_time, event.dtend.to_time)
          start_time = NOW
        else
          start_time = event.dtstart.to_time
        end

        rooms[found_room] << [
          start_time, 
          event.dtend.to_time
        ]

        debug("Added room #{found_room}")
      end
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

    candidates.map! do |room, times|
      [room, times.sort_by{ |span| span.first.to_i }]
    end

    return candidates.uniq
  end

  private

  def debug(message)
    if Sinatra::Base.development?
      puts "[DEBUG] #{message}"
    end
  end

  def events
    semaphore = Mutex.new
    events = []
    ["https://se.timeedit.net/web/chalmers/db1/public/ri663Q18Y66Z55Q5Y169X465y5Z654Y613Y7341Q517116XX4655636355111XY63415652X3Y5Y616X1347156X5165145310X16Y56156Y5443136X563Y5481Y4133056X15Y15X5363X66556031Y10Y346XX558176384Y515450X85612064058683X931YY5X854584533X9Y6855Y5117Q7.ics", "https://se.timeedit.net/web/chalmers/db1/public/ri663Q43Y88Z55Q5Y462X565y5Z855Y613Y1351Q547146XX5855437655411XY63245658X3Y5Y716X4327457X2465125397X16Y57156Y5321437X563Y5674Y4133257X15Y15X5362X67551534Y13Y346XX557126374Y515455X75618564353673X731YY5X75439473321Y67353515754653XY1Y17QX.ics", "https://se.timeedit.net/web/chalmers/db1/public/ri663Q47Y77Z55Q5Y464X465y5Z753Y613Y3331Q547146XX4755837955411XY63445652X3Y5Y716X4347457X4465145331X16Y58156Y5503438X563Y5004Y1153458X15Y15X5360X68557534Y18Y316XX550163301Y515155X05614561955653X931YY5X05180103323Y60953515751658XY1Y17QX.ics", "https://se.timeedit.net/web/chalmers/db1/public/ri663Q14Y00Z55Q5Y169X165y5Z058Y613Y1381Q517116XX1055131851701XY5317Q6.ics"].each_with_index.map do |schema, index|
      Thread.start do
        cal = Icalendar.parse(RestClient.get(schema)).first
        semaphore.synchronize do
          events += cal.events
        end

        debug("Schedule #{index} has been loaded")
      end
    end.each(&:join)

    debug("All #{events.count} schedules has been loaded")

    return events
  end
end