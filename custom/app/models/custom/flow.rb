# frozen_string_literal: true

class Custom::Flow < ApplicationRecord
  self.table_name = 'custom_flows'

  belongs_to :account
  has_many :custom_flow_sessions,
           class_name: 'Custom::FlowSession',
           foreign_key: :custom_flow_id,
           dependent: :destroy,
           inverse_of: :custom_flow

  enum :status, { draft: 0, published: 1, archived: 2 }

  validates :name, presence: true
  validates :account_id, presence: true
  validates :status, presence: true

  scope :published, -> { where(status: :published) }
  scope :draft, -> { where(status: :draft) }
end
