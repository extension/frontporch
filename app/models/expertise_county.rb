# === COPYRIGHT:
#  Copyright (c) 2005-2007 North Carolina State University
#  Developed with funding for the National eXtension Initiative.
# === LICENSE:
#  BSD(-compatible)
#  see LICENSE file or view at http://about.extension.org/wiki/LICENSE

class ExpertiseCounty < ActiveRecord::Base
  
  has_and_belongs_to_many :users
  belongs_to :expertise_location
  
  
end