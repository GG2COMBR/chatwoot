# frozen_string_literal: true

class Custom::Ai::HandoffDetectorService
  PATTERNS = [
    /\b(falar com|chamar|passar para|preciso de) (um |uma )?(atendente|humano|pessoa|operador)\b/i,
    /\b(atendente humano|suporte humano|pessoa real)\b/i,
    /\b(atendente|humano|operador)\b/i
  ].freeze

  def self.human_intent?(text)
    new(text).human_intent?
  end

  def initialize(text)
    @text = text.to_s.strip
  end

  def human_intent?
    return false if @text.blank?

    normalized = @text.downcase
    PATTERNS.any? { |pattern| pattern.match?(normalized) }
  end
end
