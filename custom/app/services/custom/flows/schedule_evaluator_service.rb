# frozen_string_literal: true

class Custom::Flows::ScheduleEvaluatorService
  DEFAULT_TIMEZONE = 'America/Sao_Paulo'
  DEFAULT_OUT_OF_OFFICE = 'Olá {{contact.name}}! Nosso horário de atendimento é de Segunda a Sexta, das 08h às 18h. Já registramos seu contato!'

  DAY_MAP = {
    0 => :sunday,
    1 => :monday,
    2 => :tuesday,
    3 => :wednesday,
    4 => :thursday,
    5 => :friday,
    6 => :saturday
  }.freeze

  class << self
    def open_now?(target, timezone: DEFAULT_TIMEZONE, at: Time.current)
      new(target, timezone: timezone, at: at).open?
    end

    def route_and_handoff!(conversation, team, config = {})
      new(config, timezone: config[:timezone] || DEFAULT_TIMEZONE).route_and_handoff!(conversation, team)
    end

    def interpolate_message(template, conversation, team = nil)
      contact_name = conversation.contact&.name || 'Cliente'
      first_name = contact_name.split(/\s+/).first || 'Cliente'
      team_name = team&.name&.titleize || 'Atendimento'
      account_name = conversation.account&.name || 'Nossa Empresa'

      (template || DEFAULT_OUT_OF_OFFICE)
        .gsub('{{contact.first_name}}', first_name)
        .gsub('{{contact.name}}', contact_name)
        .gsub('{{team.name}}', team_name)
        .gsub('{{account.name}}', account_name)
    end
  end

  def initialize(target, timezone: DEFAULT_TIMEZONE, at: Time.current)
    @target = target
    @timezone = timezone
    @at = at.in_time_zone(timezone)
  end

  def open?
    if @target.is_a?(Hash) && (@target[:enable_business_hours] == false || @target['enable_business_hours'] == false)
      return true
    end

    if @target.is_a?(Inbox)
      inbox_open?
    elsif @target.is_a?(Hash)
      hash_schedule_open?
    else
      default_business_hours_open?
    end
  end

  def route_and_handoff!(conversation, team)
    if open?
      conversation.update!(team: team, status: :open)
      { open: true, status: :open, message_sent: false }
    else
      dispatch_closed_handoff(conversation, team)
    end
  end

  private

  attr_reader :target, :timezone, :at

  def dispatch_closed_handoff(conversation, team)
    conversation.update!(team: team, status: :pending)

    template = target.is_a?(Hash) ? target[:out_of_office_message] : nil
    out_msg = self.class.interpolate_message(template, conversation, team)

    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      content: out_msg
    )

    { open: false, status: :pending, message_sent: true, content: out_msg }
  end

  def inbox_open?
    return true unless target.working_hours_enabled?

    wh = target.working_hours.find_by(day_of_week: at.wday)
    return false unless wh
    return true if wh.open_all_day?
    return false if wh.closed_all_day?

    current_minutes = (at.hour * 60) + at.min
    open_minutes = (wh.open_hour * 60) + wh.open_minutes
    close_minutes = (wh.close_hour * 60) + wh.close_minutes

    current_minutes >= open_minutes && current_minutes < close_minutes
  end

  def hash_schedule_open?
    weekly = (target[:weekly_schedule] || target['weekly_schedule'])&.with_indifferent_access
    return evaluate_day_schedule(weekly[DAY_MAP[at.wday]]) if weekly.present?

    working_days = target[:working_days] || target['working_days']
    if working_days.present?
      day_key = DAY_MAP[at.wday].to_s
      return false unless working_days.map(&:to_s).include?(day_key)

      open_time = target[:open_hour] || target['open_hour'] || '08:00'
      close_time = target[:close_hour] || target['close_hour'] || '18:00'
      return time_within_range?(open_time, close_time)
    end

    default_business_hours_open?
  end

  def evaluate_day_schedule(day_config)
    return false if day_config.blank? || day_config[:closed]

    open_time = day_config[:open] || '08:00'
    close_time = day_config[:close] || '18:00'
    time_within_range?(open_time, close_time)
  end

  def default_business_hours_open?
    return false if at.saturday? || at.sunday?

    time_within_range?('08:00', '18:00')
  end

  def time_within_range?(open_str, close_str)
    open_h, open_m = open_str.split(':').map(&:to_i)
    close_h, close_m = close_str.split(':').map(&:to_i)

    current_mins = (at.hour * 60) + at.min
    open_mins = (open_h * 60) + open_m
    close_mins = (close_h * 60) + close_m

    current_mins >= open_mins && current_mins < close_mins
  end
end
