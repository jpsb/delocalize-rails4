ActiveRecord::ConnectionAdapters::Column.class_eval do
  def type_cast_with_localization(value)
    new_value = value
    if date?
      new_value = Date.parse_localized(value) rescue value
    elsif time?
      new_value = Time.parse_localized(value) rescue value
    elsif number?
      new_value = Numeric.parse_localized(value) rescue value
    end
    type_cast_without_localization(new_value)
  end

  alias_method_chain :type_cast, :localization

  def type_cast_for_write_with_localization(value)
    if number? && I18n.delocalization_enabled?
      value = Numeric.parse_localized(value)
      if type == :integer
        value = value ? value.to_i : value
      else
        value = value ? value.to_f : value
      end
    end
    type_cast_for_write_without_localization(value)
  end

  alias_method_chain :type_cast_for_write, :localization


  ActiveRecord::Base.class_eval do
    def convert_number_column_value_with_localization(value)
      value = Numeric.parse_localized(value) if I18n.delocalization_enabled?
      value
    end

    define_method( :_field_changed? ) do |attr, old, value|
      if column = column_for_attribute(attr)
        if column.number? && column.null && (old.nil? || old == 0) && value.blank?
          # For nullable numeric columns, NULL gets stored in database for blank (i.e. '') values.
          # Hence we don't record it as a change if the value changes from nil to ''.
          # If an old value of 0 is set to '' we want this to get changed to nil as otherwise it'll
          # be typecast back to 0 (''.to_i => 0)
          value = nil
        elsif column.number?
          value = column.type_cast(convert_number_column_value_with_localization(value))
        else
          value = column.type_cast(value)
        end
      end
      old != value
    end
  end

end
