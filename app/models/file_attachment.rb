# === COPYRIGHT:
#  Copyright (c) 2005-2010 North Carolina State University
#  Developed with funding for the National eXtension Initiative.
# === LICENSE:
#  BSD(-compatible)
#  see LICENSE file or view at http://about.extension.org/wiki/LICENSE

class FileAttachment < ActiveRecord::Base
  
  belongs_to :submitted_question
  has_attached_file :attachment, :styles => { :medium => "300x300>", :thumb => "100x100>" },
  :url => "/system/:class/:attachment/:id_partition/:basename_:style.:extension"
  
  attr_accessible :attachment          
  
  before_update :randomize_attachment_file_name
  
  
  def randomize_attachment_file_name
    return if self.attachment_file_name.nil?
    extension = File.extname(attachment_file_name).downcase
    if(self.attachment_file_name_changed?)
      self.attachment.instance_write(:file_name, "#{ActiveSupport::SecureRandom.hex(16)}#{extension}")
    end
  end
  
end
