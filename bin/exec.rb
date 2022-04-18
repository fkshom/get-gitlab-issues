$LOAD_PATH[0, 0] = File.join(File.dirname(__FILE__), '..', 'lib')
require 'erb'
require 'dotenv'
require 'gitlab'
Dotenv.load

Gitlab.configure do |config|
  config.endpoint       = ENV['GITLAB_ENDPOINT']
  config.private_token  = ENV['GITLAB_TOKEN']
end

group = ENV['GROUP']
discussion_group_project = ENV['DISCUSSION_GROUP_PROJECT']
discussion_issue_id = ENV['DISCUSSION_ISSUE_ID']

class GitlabIssues
  def initialize
    clear_cache
  end

  def clear_cache
    @group_issues_cache = {}
    @discussions_cache = {}
    @issue_cache = {}
  end

  def group_issues(group, options = {})
    query_id = group + options.hash.to_s
    unless @group_issues_cache.key?(query_id)
      @group_issues_cache[query_id] = []
      new_options = options.update(per_page: 100)
      Gitlab.group_issues(group, new_options).each_page do |issues|
        @group_issues_cache[query_id] += issues.map { |issue| issue.to_hash }
      end
    end
    @group_issues_cache[query_id]
  end

  def discussions(project, issue, options = {})
    query_id = project + issue.to_s + options.hash.to_s
    unless @discussions_cache.key?(query_id)
      @discussions_cache[query_id] = []
      new_options = options.update(per_page: 100)
      Gitlab.issue_notes(project, issue, new_options).each_page do |notes|
        @discussions_cache[query_id] += notes.map { |note| note.to_hash }
      end
      @discussions_cache[query_id].reject! do |note|
        note['system'] == true
      end
    end
    @discussions_cache[query_id]
  end

  def issue(project, issue)
    query_id = project + issue.to_s
    @issue_cache[query_id] = Gitlab.issue(project, issue).to_hash unless @issue_cache.key?(query_id)
    @issue_cache[query_id]
  end
end

gitlabissues = GitlabIssues.new

class GitlabWrapper
  def initialize
    clear_cache
  end

  def clear_cache
    @cache = {}
  end

  def query(query)
    @query = query
    self
  end

  def params(*params, **options)
    @params = params
    @options = options
    self
  end

  def issue(params, _options)
    Gitlab.issue(*params)
  end

  def group_issues(params, options)
    result = []
    Gitlab.group_issues(*params, options).each_page do |items|
      result += items.map { |item| item.to_hash }
    end
    result
  end

  def issue_notes(params, options)
    result = []
    Gitlab.issue_notes(*params, options).each_page do |items|
      result += items.map { |item| item.to_hash }
    end
    result.reject! do |note|
      note['system'] == true
    end
    result
  end

  def call(options = {})
    new_options = @options.update(options)
    new_options = new_options.update(per_page: 100)
    query_id = @query.to_s + @params.hash.to_s + new_options.hash.to_s
    @cache[query_id] = send(@query, @params, new_options) unless @cache.key?(query_id)
    @cache[query_id]
  end
end

template = File.read('template.erb')
milestone = ARGV[0]
puts ERB.new(template).run
