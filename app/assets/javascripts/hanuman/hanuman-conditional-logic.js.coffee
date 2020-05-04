class @ConditionalLogic

  self = ConditionalLogic.prototype

  #scan page and find all objects with conditional logic rules
  findRules: ->
    problemWithCL = false
    $("[data-rule!=''][data-rule]").each ->
      $ruleContainer = $(this)
      #if $ruleElement.attr('data-rule').length > 0
      rules = $.parseJSON($ruleContainer.attr("data-rule"))
      $(rules).each ->
        rule = this
        console.log(rule)
        matchType = rule.match_type
        #console.log rule
        $(rule.conditions).each ->
          condition = this
          conditionQuestionId = condition.question_id
          # the container for the rule element(s), could be a single element contained in form-container-entry-item or multiple in form-container-repeater
          $ruleContainer = $ruleContainer
          # the condition container
          $conditionContainer = $ruleContainer.siblings("[data-question-id=" + conditionQuestionId + "]")
          # if condition is outside of $ruleContainer siblings context, let's looks for it globally
          if $conditionContainer.length < 1
            $conditionContainer = $("[data-question-id=" + conditionQuestionId + "]")

          if $conditionContainer.length == 0 || $conditionContainer.length > 1
            console.log "fail"
            problemWithCL = true

          # the condition element, which we need to check value for conditional logic
          $conditionElement = $conditionContainer.find(".form-control")
          # show
          if $conditionElement.length < 1
            $conditionElement = $conditionContainer.find(".form-control-static")

          if $conditionElement.length == 0
            problemWithCL = true

          # deal with any condition, once we get a hide_questions = false then we dont need to run through the rules
          hideQuestions = self.setHideQuestions(condition, $conditionElement)

          ancestorId = rule.question_id
          # bind conditions based on element type
          # text, textarea, select
          if $conditionElement.length < 2
            self.bindConditions($conditionElement)
          # radio buttons
          else
            if $conditionElement.is(":checkbox")
              # limit binding of each checkbox if data-label-value and answer are the same-kdh
              $conditionElement = $conditionContainer.find(".form-control[data-label-value='" + condition.answer.replace("/","\\/").replace("'","\\'") + "']")
              self.bindConditions($conditionElement)
            else
              for element in $conditionElement
                do (element) ->
                  self.bindConditions($(element))

          #TODO CLEAN UP THIS CODE WE HAVE STUFF IN HERE WE ARE NOT USING LIKE inRepeater
          # determine if we are in a repeater-this needs to get deleted-kdh
          inRepeater = false
          $repeater = $conditionElement.closest(".form-container-repeater")
          if $repeater.length > 0
              inRepeater = true
          if rule.conditions.length > 1
            self.checkConditionsAndHideShow(rule.conditions, ancestorId, $ruleContainer, $ruleContainer, inRepeater, matchType, rule)
          else if rule.type == "Hanuman::VisibilityRule"
            self.hideShowQuestions(hideQuestions, ancestorId, $ruleContainer, $ruleContainer, inRepeater)

    if problemWithCL
      e = new Error("conditional Logic # findRules")
      e.name = 'FAILED: conditional logic'
      console.log e.name
      Honeybadger.notify e, context:
        type: "FAILED: conditional logic => condition container or element not found or found more than once"
        details: window.location.href

    return

  #bind conditions to question
  bindConditions: ($triggerElement) ->
    $triggerElement.on "change", ->
      # pop out of condition into rules to handle all conditions defined in the rule
      # TODO it seems this is looping through ALL data-rule in the DOM instead of the data-rule associated with the element that triggered the onchange event-kdh
      $repeater = $($triggerElement).closest(".form-container-repeater")
      # check first to see if this bind is in a repeater
      if $repeater.length > 0
        $repeater.find("[data-rule!=''][data-rule]").each ->
          inRepeater = true
          $ruleElement = $(this)
          #$container = $(this).closest(".form-container-repeater")
          $container = $ruleElement
          rules = $.parseJSON($ruleElement.attr("data-rule"))
          $(rules).each ->
            rule = this
            matchType = rule.match_type
            questionId = $triggerElement.closest('.form-container-entry-item').attr('data-question-id')
            conditions = rule.conditions
            ancestorId = rule.question_id
            matchingCondition = _.where(conditions, {question_id: Number(questionId)})
            if matchingCondition.length > 0
              if conditions.length > 1
                self.checkConditionsAndHideShow(conditions, ancestorId, $ruleElement, $container, inRepeater, matchType, rule)
              else
                hideQuestions = self.setHideQuestions(conditions[0], $triggerElement)
                if rule.type == "Hanuman::VisibilityRule"
                  self.hideShowQuestions(hideQuestions, ancestorId, $ruleElement, $container, inRepeater)
      # if not then lets assume its at the top most level outside of a repeater
      else
        $($triggerElement).closest(".form-container-survey").find("[data-rule!=''][data-rule]").each ->
          inRepeater = false
          $ruleElement = $(this)
          $container = $ruleElement
          rules = $.parseJSON($ruleElement.attr("data-rule"))
          $(rules).each ->
            rule = this
            matchType = rule.match_type
            questionId = $triggerElement.closest('.form-container-entry-item').attr('data-question-id')
            conditions = rule.conditions
            ancestorId = rule.question_id
            matchingCondition = _.where(conditions, {question_id: Number(questionId)})
            if matchingCondition.length > 0
              if conditions.length > 1
                self.checkConditionsAndHideShow(conditions, ancestorId, $ruleElement, $container, inRepeater, matchType, rule)
              else
                hideQuestions = self.setHideQuestions(conditions[0], $triggerElement)
                if rule.type == "Hanuman::VisibilityRule"
                  self.hideShowQuestions(hideQuestions, ancestorId, $ruleElement, $container, inRepeater)
                else if hideQuestions == false
                  self.setLookupValue(rule.value, $ruleElement)
    return

  checkConditionsAndHideShow: (conditions, ancestorId, $ruleElement, $container, inRepeater, matchType, rule) ->
    conditionMetTracker = []
    $.each conditions, (index, condition) ->
      if inRepeater
        $conditionElement = $container.parents(".form-container-repeater").find("[data-question-id=" + condition.question_id + "]").find('.form-control')
        if $conditionElement.length < 1
          $conditionElement = $container.parents(".form-container-repeater").find("[data-question-id=" + condition.question_id + "]").find('.form-control-static')
      else
        $conditionElement = $("[data-question-id=" + condition.question_id + "]").find('.form-control')
        if $conditionElement.length < 1
          $conditionElement = $("[data-question-id=" + condition.question_id + "]").find('.form-control-static')

      if $conditionElement.is(":checkbox")# || $triggerElement.is(":radio"))
        # limit binding of each checkbox if data-label-value and answer are the same-kdh
        $conditionElement = $conditionElement.closest('.form-container-entry-item').find(".form-control[data-label-value='" + condition.answer.replace("/","\\/").replace("'","\\'") + "']")

      hideQuestions = self.setHideQuestions(condition, $conditionElement)
      conditionMet = !hideQuestions
      conditionMetTracker.push conditionMet
    # match type any (or)
    if matchType == "any"
      if conditionMetTracker.indexOf(true) > -1
        hideShow = false
      else
        hideShow = true
    # match type all
    if matchType == "all"
      if conditionMetTracker.indexOf(false) == -1
        # if no false in the array then show the conditional logic
        hideShow = false
      else
        # if one false then hide the conditioanl logic
        hideShow = true

    if rule.type == "Hanuman::VisibilityRule"
      self.hideShowQuestions(hideShow, ancestorId, $ruleElement, $container, inRepeater)
    else if hideShow == false
      self.setLookupValue(rule.value, $ruleElement)


  setLookupValue: (value, $ruleElement) ->
    answerType = $ruleElement.data('element-type')

    switch answerType
      when 'radio'
        $ruleElement.find('input[type="radio"][data-answer-choice-id=' + value + ']').prop("checked", true).trigger('change')

      when 'checkbox'
        $ruleElement.find('input[type="checkbox"]').prop("checked", true).trigger('change')

      when 'checkboxes'
        selectedOptions = value.split(",")
        $ruleElement.find('input[type="checkbox"]').each ->
          if selectedOptions.indexOf($(this).attr('value')) != -1
            $(this).prop("checked", true).trigger('change')
          else
            $(this).prop("checked", false).trigger('change')


      when 'chosenmultiselect'
        selectedOptions = value.split(",")
        $ruleElement.find('input[type="select"]').val(selectedOptions).trigger('chosen:updated');

      when 'chosenselect'
        $ruleElement.find('input[type="select"]').val(value).trigger('chosen:updated');

      when 'counter'
        $ruleElement.find('input[type="number"]').val(value)

      when 'date', 'number', 'text', 'time'
        $ruleElement.find('input[type="text"]').val(value)

      when 'textarea'
        $ruleElement.find('textarea').val(value)




  #setHideQuestions variable
  setHideQuestions: (condition, $triggerElement) ->
    operator = condition.operator
    answer = condition.answer
    # grab element type so we can branch off for checkboxes or multiselects
    element_type = $triggerElement.closest('.form-container-entry-item').attr('data-element-type')
    if element_type == 'checkboxes'
      # concatenate all the values of checboxes selected
      named_string = "input:checkbox[name='" + $triggerElement.attr('name') + "']:checked"
      selected_array = $(named_string).map(->
        $(this).attr('data-label-value')
      ).get()
      # force is equal to operator to contains since multiple checkboxes with multiple rules associated with them needs to check for contains
      hideQuestions = self.evaluateCheckboxConditions(operator, answer, selected_array)
    else if element_type == 'multiselect'
      selected_values = self.getValue($triggerElement)
      if selected_values
        selected_array = selected_values.split('|&|')
        hideQuestions = self.evaluateCheckboxConditions(operator, answer, selected_array)
      else
        return true
    # on survey show, grab oject of all saved items from checkboxes or multiselects in attribute in the HTML
    else if $triggerElement.hasClass('multiselect')
      selected_array = JSON.parse($triggerElement.attr('multiselectarray'))
      hideQuestions = self.evaluateCheckboxConditions(operator, answer, selected_array)
    # on caskey word export, radio buttons are displayed different so we need to grab the selected value from a data attribute in the HTML
    else if $triggerElement.hasClass('singleselect')
      selectedValue = $triggerElement.attr('selectedvalue')
      hideQuestions = self.evaluateCondition(operator, answer, selectedValue)
    else
      hideQuestions = self.evaluateCondition(operator, answer, self.getValue($triggerElement))

  #hide or show questions
  hideShowQuestions: (hide_questions, ancestor_id, $ruleElement, $container, inRepeater) ->
    # deal with container
    if hide_questions
      $container.addClass("conditional-logic-hidden")
      # self.clearQuestions($container)
    else
      $container.removeClass("conditional-logic-hidden")

  #clear questions
  clearQuestions: (container) ->
    #console.log container
    # clear out text fields, selects and uncheck radio and checkboxes
    #TODO set these to default values once we implement default values - kdh
    # container.find("input[type!=hidden]").val("")
    textFields = container.find(":text")
    textFields.each ->
      if $(this).attr("data-default-answer") && $(this).data("default-answer") != "null"
        $(this).val($(this).data("default-answer"))
      else
        $(this).val("")

    textAreas = container.find("textarea")
    textAreas.each ->
      if $(this).attr("data-default-answer") && $(this).data("default-answer") != "null"
        $(this).val($(this).data("default-answer"))
      else
        $(this).val("")

    # un-select dropdown
    selects = container.find("select")
    selects.each ->
      if $(this).attr("data-default-answer") && $(this).data("default-answer") != "null"
        $(this).val($(this).data("default-answer"))
      else
        $(this).val("")

      $(this).trigger("chosen:updated") if $(this).hasClass('chosen')

    # uncheck all checkboxes
    checkboxes = container.find(":checkbox")
    checkboxes.each ->
      if $(this).attr("data-default-answer") && $(this).data("default-answer") == "true"
        $(this).prop('checked', true)
      else
        $(this).prop('checked', false)

    # un-select radio buttons
    radiobuttons = container.find(":radio")
    radiobuttons.each ->
      if $(this).attr("data-default-answer") && $(this).data("default-answer") != "null" && $(this).data("label-value") == $(this).data("default-answer")
        $(this).prop('checked', true)
      else
        $(this).prop('checked', false)

    multiselects = container.find("select[multiple]")
    multiselects.each ->
      id = $(this).attr('id')
      $('#' + id + ' option:selected').removeAttr("selected")
      $(this).trigger("chosen:updated") if $(this).hasClass('chosen-multiselect')

    # kdh commenting out triggering change event because it is having an exponential effect and causing performance problems on conditional logic #157849774
    # trigger onchange event which is needed for embedded conditional logic
    # container.find('.form-control').trigger('change')

  #evaluate conditional logic rules
  evaluateCondition: (operator, answer, value) ->
    hide_questions = true
    switch operator
      when "is equal to"
        if value == answer then hide_questions = false
      when "is not equal to"
        if value != answer then hide_questions = false
      when "is empty"
        if !value || (value && value.length < 1) then hide_questions = false
      when "is not empty"
        if value && value.length > 0 then hide_questions = false
      when "is greater than"
        if $.isNumeric(value)
          if parseFloat(value) > parseFloat(answer) then hide_questions = false
      when "is less than"
        if $.isNumeric(value)
          if parseFloat(value) < parseFloat(answer) then hide_questions = false
      when "starts with"
        if value and value.slice(0, answer.length) == answer then hide_questions = false
      when "contains"
        if value and value.indexOf(answer) > -1 then hide_questions = false
    return hide_questions

  # need a special evaluate condition method to determine if one of the values in the checkbox array matches the condition
  evaluateCheckboxConditions: (operator, answer, value_array) ->
    hide_questions = true
    for value in value_array
      switch operator
        when "is equal to"
          if value == answer
            hide_questions = false
        when "is not equal to"
          if value != answer
            hide_questions = false
        when "is empty"
          if !value || (value && value.length) < 1
            hide_questions = false
        when "is not empty"
          if value && value.length > 0
            hide_questions = false
        when "is greater than"
          if $.isNumeric(value)
            if parseFloat(value) > parseFloat(answer)
              hide_questions = false
        when "is less than"
          if $.isNumeric(value)
            if parseFloat(value) < parseFloat(answer)
              hide_questions = false
        when "starts with"
          if value and value.slice(0, answer.length) == answer
            hide_questions = false
        when "contains"
          if value and value.indexOf(answer) > -1
            hide_questions = false
      # break out of loop if we found a match
      if hide_questions == false
        return hide_questions
    return hide_questions

  # get value of triggering question
  getValue: ($conditionElement) ->
    if $conditionElement.is(":radio")
      selected = $("input[type='radio'][name='" + $conditionElement.attr('name') + "']:checked")
      if selected.length > 0
        if selected.attr('data-label-value')
          return selected.attr('data-label-value')
        else
          return selected.val()
      else
        return
    if $conditionElement.is(":checkbox")
      if $conditionElement.is(":checked")
        if $conditionElement.attr('data-label-value')
          return $conditionElement.attr('data-label-value')
        else
          return $conditionElement.val()
      else
        return
    if $conditionElement.is('select[multiple]')
      if $conditionElement.siblings(".chosen-container").find(".chosen-choices li span").size() > 0
        option_strings = []
        $conditionElement.siblings(".chosen-container").find(".chosen-choices li span").each ->
          option_strings.push this.innerHTML
        return option_strings.join("|&|")
      else if $conditionElement.is(".selectize-taxon-select") && $conditionElement.children().size() > 0
        option_strings = []
        $conditionElement.children().each ->
          option_strings.push this.innerHTML
        return option_strings.join("|&|")
      else
        return
    if $conditionElement.is('select')
      return $('#' + $conditionElement.attr('id') + ' option:selected').text()
    if $conditionElement.is("p")
      #remove carriage returns and trim leading and trailing whitespace
      #need to refactor to look for value in element data- attribute instead of from html rendered output
      return $conditionElement.text().replace(/\↵/g,"").trim()
    # survey report preview
    if $conditionElement.is('td')
      if $conditionElement.hasClass('checklist')
        return $conditionElement.find('span.hidden-answer').text().replace(/\↵/g, '').trim()
      else
        return $conditionElement.text().replace(/\↵/g, '').trim()
    $conditionElement.val()

$ ->
  if $('input#survey_survey_template_id').length
    #call findRules on document ready
    cl = new ConditionalLogic
    cl.findRules()
