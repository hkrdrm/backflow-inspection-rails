# Append-only record of a module's platform-wide status changing, and by whom
# (nil when done from seeds or the console).
class PlatformModuleEvent < Sequel::Model
  many_to_one :account
end
