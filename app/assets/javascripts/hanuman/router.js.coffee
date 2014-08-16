# For more information see: http://emberjs.com/guides/routing/

App.Router.map ()->
  # @resource('posts')
  @resource 'survey_templates', ->
    @resource('survey_template', { path: '/:survey_template_id' })

App.IndexRoute = Ember.Route.extend(
  model: ->
    return ['red', 'yellow', 'blue']
)

App.SurveyTemplatesRoute = Ember.Route.extend({
  model: ->
    @store.find('survey_templates')
})

App.SurveyTemplateRoute = Ember.Route.extend({
  model: (params) ->
    @store.find('survey_template', params.survey_template_id)
})