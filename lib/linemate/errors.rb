# frozen_string_literal: true

module Linemate
  class Error < StandardError; end

  class ConnectionNotEstablished < Error; end

  class UnknownColumn < Error; end

  class NotNullViolation < Error; end

  class RecordNotFound < Error; end

  class AssociationError < Error; end
end
