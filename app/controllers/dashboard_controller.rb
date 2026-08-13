class DashboardController < ApplicationController
  layout "app"

  before_action :authenticate

  # ---------------------------------------------------------------------------
  # SKETCH DATA
  #
  # There are no properties, inspections, or certificates tables yet, so every
  # number and row below is sample content lifted from the design mockup. It
  # exists so the layout can be reviewed with realistic shapes. Delete this
  # constant wholesale once real models land — nothing else here depends on it.
  # ---------------------------------------------------------------------------
  SAMPLE = {
    stats: [
      { label: "Upcoming Inspections", value: 8,  icon: :calendar,    tone: :brand, footnote: "Next: May 15, 2025" },
      { label: "Completed This Year",  value: 24, icon: :check,       tone: :ok,    footnote: "View all" },
      { label: "Past Due",             value: 2,  icon: :warning,     tone: :warn,  footnote: "View past due" },
      { label: "Appliances Tracked",   value: 22, icon: :droplet,    tone: :brand, footnote: "View all" }
    ],
    inspections: [
      { date: "May 15, 2025", time: "9:00 AM",  property: "Main Street Plaza", address: "123 Main Street",     plumber: "Pike Plumbing Co.",  status: "Scheduled" },
      { date: "May 20, 2025", time: "10:30 AM", property: "Oak Grove School",  address: "200 Oak Avenue",      plumber: "Clearflow Plumbing", status: "Scheduled" },
      { date: "May 22, 2025", time: "1:00 PM",  property: "Industrial Park",   address: "875 Industrial Park", plumber: "Riverbend Plumbing", status: "Scheduled" },
      { date: "May 28, 2025", time: "9:00 AM",  property: "Community Center",  address: "301 Center St",       plumber: "Pike Plumbing Co.",  status: "Pending" },
      { date: "May 30, 2025", time: "11:00 AM", property: "City Hall",         address: "100 Government St",   plumber: "Clearflow Plumbing", status: "Pending" }
    ],
    status_overview: [
      { label: "Up to date", count: 24, color: "var(--color-brand)" },
      { label: "Scheduled",  count: 8,  color: "var(--color-ok)" },
      { label: "Past due",   count: 2,  color: "var(--color-warn-strong)" }
    ],
    activity: [
      { icon: :calendar,    tone: :brand, title: "Inspection scheduled", subject: "123 Main Street", day: "May 10", time: "9:42 AM" },
      { icon: :check,       tone: :ok,    title: "Inspection completed", subject: "200 Oak Avenue",  day: "May 8",  time: "2:15 PM" },
      { icon: :upload,      tone: :brand, title: "Report uploaded",      subject: "Industrial Park", day: "May 8",  time: "1:03 PM" },
      { icon: :warning,     tone: :warn,  title: "Inspection past due",  subject: "Warehouse #4",    day: "May 6",  time: "8:30 AM" }
    ],
    assurances: [
      { icon: :check,        title: "Stay Compliant",        body: "Stay up to date with annual inspections and avoid costly penalties." },
      { icon: :user,         title: "Licensed Professionals", body: "We connect you with licensed, certified plumbers you can trust." },
      { icon: :document,     title: "Easy Documentation",    body: "Access reports and certificates anytime, all in one place." }
    ]
  }.freeze

  def show
    @data = SAMPLE
    @status_total = @data[:status_overview].sum { |slice| slice[:count] }
  end
end
