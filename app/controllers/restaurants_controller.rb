# encoding: UTF-8
require 'slack/post'

class RestaurantsController < ApplicationController
  def lunch_of_the_day
    # TODO: Optimize active record queries. This is probably not very smart way to do this.

    r = Restaurant.where("lower(restaurants.name) like ?", "%#{params[:text].downcase}%").first

    not_found if r.nil?

    l = Lunch.find_by_restaurant_id_and_date(r.id, Date.today)

    not_found if l.nil?

    lunch_items = LunchItem.joins(:lunch => :restaurant)
      .where("restaurants.id = ?", r.id)
      .where("lunches.date = ?", Date.today)

    fallback_response = construct_fallback_response r, lunch_items

    post_to_slack fallback_response, r, l, lunch_items, params[:channel_name]

    feedback = "Ravintolan #{params[:text]} lounaslista töräytetty kanavalle #{params[:channel_name]}."
    
    respond_to do |format|
      format.html { render :text => feedback}
      format.text { render :text => feedback}
    end
  end

  private  

  def post_to_slack(fallback_response, restaurant, lunch, lunch_items, channel_name)
    Slack::Post.configure(
      webhook_url: ENV['SLACK_WEB_HOOK_URI']
    )

    dishes = lunch_items_to_a lunch_items

    attachments = [
      {
        fallback: fallback_response,
        color: "#439FE0",
        fields: dishes
      }
    ]

    stars = ""
    [lunch.votes, 5].min.times do
      stars << ":star:"
    end

    stars = "<#{stars}>" unless stars.empty?

    Slack::Post.post_with_attachments ":fork_and_knife: *#{restaurant.name} #{stars} tarjoaa tänään lounaalla:*", attachments, "##{channel_name}"
  end

  def construct_fallback_response(restaurant, lunch_items)
      response = ":fork_and_knife: #{restaurant.name} tarjoaa tänään lounaalla:"

      unless lunch_items.empty?
        lunch_items.each do |li|
          response += "\n#{li.description}"
        end
      else
        response += "\nEi mitään erityistä.\n:neutral_face:"
      end

      return response
  end

  def lunch_items_to_a(lunch_items)
    dishes = []

    unless lunch_items.empty?
      lunch_items.each do |li|
        dishes << { value: li.description, short: false }
      end
    else
      dishes << { value: "Ei mitään erityistä.\n:neutral_face:", short: false }
    end

    return dishes
  end
end
