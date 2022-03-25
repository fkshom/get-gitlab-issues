$LOAD_PATH[0, 0] = File.join(File.dirname(__FILE__), '..', 'lib')

require 'dotenv'
require 'gitlab'
Dotenv.load

Gitlab.configure do |config|
  config.endpoint       = 'https://gitlab.com/api/v4'
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

priority_low = gitlabissues.group_issues(group, {
                                           labels: 'Priority: Low'
                                         })
puts 'priority_low'
puts '=' * 50
pp priority_low

discussions_by_user = gitlabissues.discussions(discussion_group_project, discussion_issue_id, {})
puts 'discussions_by_user'
puts '=' * 50
pp discussions_by_user

discussion_issue = gitlabissues.issue(discussion_group_project, discussion_issue_id)
puts 'discussion_issue'
puts '=' * 50
pp discussion_issue

priority_low_and_type_feature = gitlabissues.group_issues(group, {
                                                            labels: 'Priority: Low,Type: Feature'
                                                          })
puts 'priority_low_and_type_feature'
puts '=' * 50
pp priority_low_and_type_feature

puts <<~"EOS"
  - issue数
    - Priority Low: #{priority_low.count}
      - うち、Type: Feature: #{priority_low_and_type_feature.count}
  - コメント数: #{discussions_by_user.count} ( #{discussion_issue['title']} )
EOS

issues_group_by_epic = {}
gitlabissues.group_issues(group, {
                            labels: 'Priority: Low'
                          }).each do |issue|
  epicname = if issue['epic']
               issue['epic']['title']
             else
               'その他'
             end
  issues_group_by_epic[epicname] ||= []
  issues_group_by_epic[epicname] << issue
end

other_issues = issues_group_by_epic.delete('その他')
issues_group_by_epic['その他'] = other_issues if other_issues

issues_group_by_epic.each do |epicname, issues|
  puts "- #{epicname}"
  issues.each do |issue|
    puts "  - #{issue['title']}"
  end
end
