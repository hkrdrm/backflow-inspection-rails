module ModulesHelper
  # A module's pages with resolved hrefs, and which one is current. The
  # current page is the one whose path is the longest prefix of this request's
  # path, so a page stays current on its sub-pages (/backflow/testers/new
  # keeps "Testers" current, not "Overview"). Nothing is current unless the
  # request is inside this module.
  def module_pages(definition)
    pages = definition.pages.map { |page| page.merge(href: public_send(page[:path])) }
    current = if current_module&.key == definition.key
                pages.select { |page| request.path == page[:href] || request.path.start_with?("#{page[:href]}/") }
                     .max_by { |page| page[:href].length }
    end
    pages.map { |page| page.merge(current: page.equal?(current)) }
  end
end
