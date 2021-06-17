class @ConditionalLogic

  self = ConditionalLogic.prototype
  self.boundElements = []

  #scan page and find all objects with conditional logic rules
  findRules: ($repeaterContainer) ->
    self.allowCascade = false
    problemWithCL = false
    $("[data-rule!=''][data-rule]").each ->
      $ruleContainer = $(this)
      #if $ruleElement.attr('data-rule').length > 0
      rules = $.parseJSON($ruleContainer.attr("data-rule"))
      $(rules).each ->
        rule = this
        matchType = rule.match_type

        shouldRunRepeaterCalcs = false

        if $repeaterContainer != null && $repeaterContainer[0].contains($ruleContainer[0])
          shouldRunRepeaterCalcs = true

        $(rule.conditions).each ->
          conditionQuestionId = this.question_id
          # the container for the rule element(s), could be a single element contained in form-container-entry-item or multiple in form-container-repeater
          $ruleContainer = $ruleContainer
          # the condition container
          $conditionContainer = $ruleContainer.siblings("[data-question-id=" + conditionQuestionId + "]")
          # if condition is outside of $ruleContainer siblings context, let's looks for it globally
          if $conditionContainer.length < 1
            $conditionContainer = $("[data-question-id=" + conditionQuestionId + "]")

          if ($conditionContainer.length == 0 || $conditionContainer.length > 1) && rule.type != 'Hanuman::CalculationRule'
            problemWithCL = true

          # the condition element, which we need to check value for conditional logic
          $conditionElement = $conditionContainer.find(".form-control")

          # show
          if $conditionElement.length < 1
            $conditionElement = $conditionContainer.find(".form-control-static")

          if $conditionElement.length == 0 && rule.type != 'Hanuman::CalculationRule'
            problemWithCL = true

          if $repeaterContainer != null && !shouldRunRepeaterCalcs
            $conditionElement.each ->
              if $repeaterContainer[0].contains(this)
                shouldRunRepeaterCalcs = true
                return

          # deal with any condition, once we get a hide_questions = false then we dont need to run through the rules
          hideQuestions = self.setHideQuestions(this, $conditionElement)

          ancestorId = rule.question_id
          # bind conditions based on element type
          # text, textarea, select
          if $conditionElement.length < 2
            self.bindConditions($conditionElement, rule, $ruleContainer, this.id)
          # radio buttons
          else
            if $conditionElement.is(":checkbox")
              # limit binding of each checkbox if data-label-value and answer are the same-kdh
              if rule.type != 'Hanuman::CalculationRule'
                $conditionElement = $conditionContainer.find(".form-control[data-label-value='" + this.answer.replace("/","\\/").replace("'","\\'") + "']")

              self.bindConditions($conditionElement, rule, $ruleContainer, this.id)
            else
              for element in $conditionElement
                do (element) ->
                  self.bindConditions($(element), rule, $ruleContainer, this.id)

          #TODO CLEAN UP THIS CODE WE HAVE STUFF IN HERE WE ARE NOT USING LIKE inRepeater
          # determine if we are in a repeater-this needs to get deleted-kdh
          inRepeater = false
          $repeater = $conditionElement.closest(".form-container-repeater")
          if $repeater.length > 0
              inRepeater = true

          if rule.type != "Hanuman::CalculationRule"
            self.checkConditionsAndHideShow(rule.conditions, ancestorId, $ruleContainer, $ruleContainer, inRepeater, matchType, rule, true)

        if rule.type == "Hanuman::CalculationRule" && ($repeaterContainer == null || shouldRunRepeaterCalcs)
          self.updateCalculation(rule, $ruleContainer)

          # need the direct returns so that the nested loops don't get broken when they're compiled to JS
          return
        return

    if problemWithCL
      e = new Error("conditional Logic # findRules")
      e.name = 'FAILED: conditional logic'
      Honeybadger.notify e, context:
        type: "FAILED: conditional logic => condition container or element not found or found more than once"
        details: window.location.href

    self.allowCascade = true
    return

  #bind conditions to question
  bindConditions: ($triggerElement, rule, $ruleContainer, conditionId) ->

    ## Don't double-bind calculations
    ## We need to store the parameter element, calculated element, condition, and rule in order to not to exclude any necessary bindings
    if rule.type == "Hanuman::CalculationRule"
      idx = self.boundElements.findIndex (el) ->
        return $triggerElement[0] == el[0] && conditionId == el[1] && rule.id == el[2] && $ruleContainer[0] == el[3]
      return if idx != -1
      self.boundElements.push([$triggerElement[0], conditionId, rule.id, $ruleContainer[0]])

    $triggerElement.on "change", ->
      ## If this is a calculation rule, we don't care about conditional logic, we just want to re-run the calculations since a value has changed
      if rule.type == "Hanuman::CalculationRule"
        self.updateCalculation(rule, $ruleContainer, true)
        return

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
            matchType = this.match_type
            questionId = $triggerElement.closest('.form-container-entry-item').attr('data-question-id')
            conditions = this.conditions
            ancestorId = this.question_id
            matchingCondition = _.where(conditions, {question_id: Number(questionId)})
            if matchingCondition.length > 0
              if conditions.length > 1
                self.checkConditionsAndHideShow(conditions, ancestorId, $ruleElement, $container, inRepeater, matchType, this, false)
              else
                hideQuestions = self.setHideQuestions(conditions[0], $triggerElement)
                if this.type == "Hanuman::VisibilityRule"
                  self.hideShowQuestions(hideQuestions, ancestorId, $ruleElement, $container, inRepeater)
      # if not then lets assume its at the top most level outside of a repeater
      else
        $($triggerElement).closest(".form-container-survey").find("[data-rule!=''][data-rule]").each ->
          inRepeater = false
          $ruleElement = $(this)
          $container = $ruleElement
          rules = $.parseJSON($ruleElement.attr("data-rule"))
          $(rules).each ->
            matchType = this.match_type
            questionId = $triggerElement.closest('.form-container-entry-item').attr('data-question-id')
            conditions = this.conditions
            ancestorId = this.question_id
            matchingCondition = _.where(conditions, {question_id: Number(questionId)})
            if matchingCondition.length > 0
              if conditions.length > 1
                self.checkConditionsAndHideShow(conditions, ancestorId, $ruleElement, $container, inRepeater, matchType, this, false)
              else
                hideQuestions = self.setHideQuestions(conditions[0], $triggerElement)
                if this.type == "Hanuman::VisibilityRule"
                  self.hideShowQuestions(hideQuestions, ancestorId, $ruleElement, $container, inRepeater)
                else if hideQuestions == false
                  self.setLookupValue(this.value, $ruleElement)
    return

  checkConditionsAndHideShow: (conditions, ancestorId, $ruleElement, $container, inRepeater, matchType, rule, onLoad) ->
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
    else if !onLoad && hideShow == false && rule.type == "Hanuman::LookupRule"
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
    if ($conditionElement[0] && $conditionElement[0].selectize)
      value = $conditionElement[0].selectize.getValue()
      if value.constructor == Array
        option_strings = []
        $.each value, (index, optionId) ->
          option_strings.push $($conditionElement[0].selectize.getItem(optionId)[0]).text()

        return option_strings.join("|&|")
      else
        return $($conditionElement[0].selectize.getItem(value)[0]).text()

    if $conditionElement.is(":radio")
      selected = $("input[type='radio'][name='" + $conditionElement.attr('name') + "']:checked")
      if selected.length > 0
        if selected.attr('data-label-value')
          return selected.attr('data-label-value')
        else
          return selected.val()
      else
        return

    if $conditionElement.is(":checkbox") && $conditionElement.parents('.form-container-entry-item').data('element-type') == 'checkboxes'
      option_strings = []
      $.each $conditionElement, (index, checkbox) ->
        if $(checkbox).is(":checked")
          option_strings.push $(checkbox).attr('data-label-value')
      return option_strings.join("|&|")

    if $conditionElement.is(":checkbox")
      if $conditionElement.is(":checked")
        if $conditionElement.attr('data-label-value')
          return $conditionElement.attr('data-label-value')
        else
          return $conditionElement.val()
      else
        return

    if $conditionElement.is('select[multiple]')
      if $conditionElement.find("option:selected").length > 0
        option_strings = []
        $conditionElement.find("option:selected").each ->
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
      text = $('#' + $conditionElement.attr('id') + ' option:selected').text()
      if text == 'Please select'
        return undefined
      else
        return text

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

  ## AN May 2020 - Start calculated fields code
  # This method triggers an update of the calculations for the given rule's target question
  updateCalculation: (rule, $ruleContainer) ->
    parameters = {} # used to store the survey data object passed to the calculated fields expresssion
    $target = $ruleContainer.find('.form-control') # the question we are calculating a value for
    $targetRepeater = $ruleContainer.closest(".form-container-repeater") # the parent repeater of the target, if it exists
    targetType = $ruleContainer.data('element-type') # the form control type of the target

    $.each rule.conditions, (index, condition) ->

      # If the target question (the one we are calculating a value for) is inside a repeater AND the parameter question is inside a repeater,
      # we only want the parameter if it's in the same repeater instance as the target
      if $targetRepeater.length > 0 && $('[data-question-id="' + condition.question_id + '"]').closest(".form-container-repeater").length > 0
        $question = $targetRepeater.find('[data-question-id="' + condition.question_id + '"]')
      else
        $question = $('[data-question-id="' + condition.question_id + '"]')

      elementType = $question.data('element-type') # the form control type of the parameter question
      columnName = $question.data('api-column-name') # the api column name of the parameter, used to generate the variable name
      $repeater = $question.closest(".form-container-repeater") # the parent parameter of the target, if it exists

      # If the parameter question is inside a repeater, but the target is top-level, we want to make an array out of the parameter question across all repeater instances
      if $repeater.length > 0 && $targetRepeater.length == 0
        entries = []
        $.each $question, (index, entry) ->
          value = self.getNativeValue($(entry).find('.form-control'), elementType)
          entries.push(value)
        parameters[columnName] = entries

      # Otherwise, we only want the parameter question (either it is top level, or in the same repeater instance as the target)
      else
        $conditionElement = $question.find('.form-control')
        value = self.getNativeValue($conditionElement, elementType)
        parameters[columnName] = value

    self.interpreter = new Interpreter(rule.script, (interpreter, globalObject) ->
      # creates a function that can be called from the interpreter context,
      # which allows us to extract the calculation result and update the UI
      outputWrapper = (result) -> self.setCalculationResult($target, result, targetType)
      interpreter.setProperty(globalObject, 'setResult', interpreter.createNativeFunction(outputWrapper))

      # get all of the parameter questions, inject them into the interpreter as $api_column_name variables
      $.each parameters, (key, value) ->
        interpreter.setProperty(globalObject, '$' + key, interpreter.nativeToPseudo(value))
    )

    self.interpreter.run()

  # This method takes a value from the interpreter and updates the UI
  # $target: jQuery object for the target question
  # pseudoResult: interpreter object containing the calculation result
  # elementType: the form control type of the target
  setCalculationResult: ($target, pseudoResult, elementType) ->
    result = self.interpreter.pseudoToNative(pseudoResult) # converts from an interpreter object to a native JS object

    if elementType == 'checkbox' && typeof result == 'boolean'
      $target.prop("checked", result)

    else if (elementType == 'number' || elementType == 'counter') && typeof result == 'number'
      $target.val(result)

    else if (elementType == 'text' || elementType ==  'textarea' || elementType == 'time') && typeof result == 'string'
      $target.val(result)

    else if elementType == 'date' && typeof result == 'string'
      $target.datepicker("setDate", new Date(result))

    else if elementType == 'checkboxes' && Array.isArray(result)
      $.each $target, (index, checkbox) ->
        $(checkbox).prop("checked", result.indexOf($(checkbox).attr('data-label-value')) != -1)

    else if elementType == 'multiselect' && Array.isArray(result)
      if $target.hasClass('chosen-multiselect')
        $target.find('option').prop('selected', false)
        $.each result, (index, optionText) -> $target.find('option:contains(' + optionText + ')').prop('selected', true);

      else if $target.hasClass('selectized')
        $target[0].selectize.clear(true)
        $.each $target[0].selectize.options, (index, option) ->
          if result.indexOf(option.text) != -1
            $target[0].selectize.addItem(option.value, false)

    else if elementType == 'select' && typeof result == 'string'
      if $target.hasClass('chosen-select')
        $target.find('option').prop('selected', false)
        $target.find('option:contains(' + result + ')').prop('selected', true);

      else if $target.hasClass('selectized')
        $target[0].selectize.clear(true)
        $.each $target[0].selectize.options, (index, option) ->
          if option.text == result
            $target[0].selectize.addItem(option.value, false)
            return

    else if elementType == 'radio' && typeof result == 'string'
      $.each $target, (index, radio) ->
        $(radio).prop("checked", $(radio).attr('data-label-value') == result)

    # If the type of the calculation result doesn't match the element type, or is null/undefined, clear the target
    else
      if elementType == 'checkbox'
        $target.prop("checked", false)

      else if elementType == 'checkboxes' || elementType == 'radio'
        $.each $target, (index, option) ->
          $(option).prop("checked", false)

      else if elementType == 'multiselect' || elementType == 'select'
        if $target.hasClass('chosen-select') || $target.hasClass('chosen-multiselect')
          $target.find('option').prop('selected', false)

        else if $target.hasClass('selectized')
          $target[0].selectize.clear(true)

      else
        $target.val('')

    # for performance reasons, only cascade CL and other calcs if permitted
    if self.allowCascade
      if elementType == 'checkboxes' || elementType == 'radio'
        $.each $target, (index, checkbox) ->
          $(checkbox).trigger('change')

      else if elementType == 'multiselect' || elementType == 'select'
        if $target.hasClass('chosen-select') || $target.hasClass('chosen-multiselect')
          $target.trigger("chosen:updated")

        else if $target.hasClass('selectized')
          $($target[0]).trigger('change')

      else
        $target.trigger('change')


  # converts the string value taken from a given input to a native JS value that we can pass to the interpreter
  getNativeValue: ($input, elementType) ->
    stringValue = self.getValue($input)

    if elementType == 'checkbox'
      return stringValue == 'true'

    if elementType == 'number' || elementType == 'counter'
      if $.isNumeric(stringValue)
        return parseFloat(stringValue)
      else
        return 0

    if elementType == 'multiselect' || elementType == 'checkboxes'
      if stringValue == undefined || stringValue == null || stringValue.trim() == ''
        return []
      else
        return stringValue.split('|&|')

    if elementType == 'date'
      return $input.datepicker('getDate')

    if stringValue == undefined || stringValue == null || stringValue.trim() == ''
      return null

    return stringValue

$ ->
  if $('input#survey_survey_template_id').length
    #call findRules on document ready
    cl = new ConditionalLogic
    cl.findRules(null)
