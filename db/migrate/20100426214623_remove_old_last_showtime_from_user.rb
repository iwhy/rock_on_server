class RemoveOldLastShowtimeFromUser < ActiveRecord::Migration
  def self.up
    remove_column :users, :old_last_showtime       
  end

  def self.down
    add_column :users, :old_last_showtime, :string          
  end
end
