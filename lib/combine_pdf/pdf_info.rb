module CombinePDF
  class PDFInfo

    # if we're passed a date object, return a formatted string
    # otherwise just use the string we've been passed
    def self.format_date(new_date)
      return new_date.strftime "D:%Y%m%d%H%M%S%:::z'00" if new_date.respond_to?(:strftime)
      new_date
    end
  end

  class PDF

    def title
      self.info[:Title]
    end

    def title=(new_title = nil)
      self.info[:Title] = new_title
    end

    def author
      self.info[:Author]
    end

    def author=(new_author = nil)
      self.info[:Author] = new_author
    end

    def subject
      self.info[:Subject]
    end

    def subject=(new_subject = nil)
      self.info[:Subject] = new_subject
    end

    def keywords
      self.info[:Keywords]
    end

    def keywords=(new_keywords = nil)
      self.info[:KeyWords] = new_keywords
    end

    def creator
      self.info[:Creator]
    end

    def creator=(new_creator = nil)
      self.info[:Creator] = new_creator
    end

    def producer
      self.info[:Producer]
    end

    def producer=(new_producer = nil)
      self.info[:Producer] = new_producer
    end

    def creation_date
      self.info[:CreationDate]
    end

    def creation_date=(new_creation_date = nil)
      self.info[:CreationDate] = PDFInfo.format_date(new_creation_date)
    end

    def mod_date
      self.info[:ModDate]
    end

    def mod_date=(new_mod_date = nil)
      self.info[:ModDate] = PDFInfo.format_date(new_mod_date)
    end

    def trapped
      self.info[:Trapped]
    end

    def trapped=(new_trapped = nil)
      self.info[:Trapped] = new_trapped
    end

  end

end