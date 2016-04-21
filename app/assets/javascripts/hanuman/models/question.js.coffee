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

  numChildren: (->
    if @.get('ancestry')?
      Array(@.get('ancestry').split('/').length + 1).join("==> ")
  ).property('ancestry')

  isContainer: (->
    if @.get('answerType').get('name') is 'section'
      return true
    else
      return false
  ).property('answerType')
  ruleMatchType: (->
    if @.get('rule')
      if @.get('rule').get('matchType') is "all"
        return "AND"
      else
        return "OR"
  ).property('rule')
})
