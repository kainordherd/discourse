# frozen_string_literal: true

module DiscourseAi
  module Summarization
    class PublishedSummary
      def initialize(topic_view)
        @topic_view = topic_view
      end

      def eligible?
        topic = @topic_view.topic
        SiteSetting.ai_summaries_for_crawlers && SiteSetting.ai_summarization_enabled &&
          !SiteSetting.login_required && @topic_view.page == 1 &&
          !@topic_view.single_post_request? && topic.regular? && topic.visible &&
          !topic.category&.read_restricted && Guardian.new.can_see?(topic)
      end

      def summary
        return @summary if defined?(@summary)

        @summary = nil
        return unless eligible?

        cached_summary =
          DiscourseAi::TopicSummarization.for(
            @topic_view.topic,
            nil,
            scope: @topic_view.guardian,
          ).cached_summary
        if cached_summary&.summarized_text.present? &&
             Guardian.new.can_see_summary?(@topic_view.topic, cached_summary:)
          @summary = cached_summary
        end
        @summary
      end

      def cooked
        @cooked ||= PrettyText.cook(summary.summarized_text, topic_id: @topic_view.topic.id)
      end

      def markdown
        MarkdownEndpoint::CookedProcessor.to_markdown(cooked, post_url: @topic_view.topic.url)
      end
    end
  end
end
