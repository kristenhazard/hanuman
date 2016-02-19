App.Question = DS.Model.extend({
  questionText: DS.attr('string')
  answerType: DS.belongsTo('answerType', {async: true})
  answerChoices: DS.hasMany('answerChoice', {async: true})
  sortOrder: DS.attr('number')
  surveyStep: DS.belongsTo('surveyStep')
  required: DS.attr('boolean')
  externalDataSource: DS.attr('string')
  hidden: DS.attr('boolean')
  ancestry: DS.attr('string')
  railsId: DS.attr('number')
  rule: DS.belongsTo('rule', {async: true})

  childQuestion: (->
    if @.get('ancestry')?
      return true
    else
      return false
  ).property('ancestry')
})
