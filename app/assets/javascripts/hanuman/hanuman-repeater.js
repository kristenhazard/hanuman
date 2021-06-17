$(document).ready(function(){

  duplicatedRepeatersOnEdit = []
  var selectizeElements = {};

  updateRepeaterControls()
  updateRepeaterIds()

  // clicking on button to add repeater
  $('.form-container-survey').on("click", '.duplicate-form-container-repeater', function(e){
    e.preventDefault();
    e.stopPropagation();

    $scrollPosition = $(this).offset().top - 50;

    // unbinding events on plugins

    $('.datepicker').datepicker('destroy');
    // cloudinary events
    $.cleanData( $('input.cloudinary-fileupload[type=file]') );

    // find and clone container
    var container = $(this).closest('.form-container-repeater');
    unbindChosenTypes(container);
    $clonedContainer = container.clone(true);
    var parentRepeater = $clonedContainer.parent().closest(".form-container-repeater");

    // remove hidden field observation ids
    $($clonedContainer).find('.hidden-field-observation-id').remove();
    // remove data-observation-id at the repeater level
    $($clonedContainer).removeAttr('data-observation-id')

    //************** BEGIN repeater ids
    repeaterInputs = $clonedContainer.find(".repeater-id")
    repeaterClosestPanel = $(this).parents(".panel-body")
    //************ END repeater ids

    // collect all container items inside cloned container for iteration later to update all attributes
    var containerItems = $($clonedContainer).find('.form-container-entry-item');

    destroyDuplicateChildRepeaters($clonedContainer);

    // loop through collected container items and update attributes with timestamps
    // CONTAINER ITEMS ARE RELATIVE TO CLONED CONTAINER, THINK OF CLONED CONTAINER AS A SECONDARY DOM OF ITS OWN.
    updateDom(containerItems, $clonedContainer);

    // set cloned container to display none for fading in
    $clonedContainer.attr("style", "display: none;").addClass("new-clone");
    // commenting out because we don't use fancy preview code for docs and videos, if we bring this back probably need this at this point
    clearFilePreviewContainers($clonedContainer);

    // clear values
    clearValues($clonedContainer);

    // we need to stringiy and reset before appending to dom becuase without this, certain js events were getting
    // triggered on the current repeater as well as the repeater above it
    stringifyAndResetContainer($clonedContainer);
    $(container).after($clonedContainer);

    $newClone = $(".new-clone");

    $newClone.delay("100").fadeIn(1000).removeClass("new-clone");

    setTimeout(function() {
      $("html, body").animate({
        scrollTop: $scrollPosition
      }, 500);
    }, 200);

    // TODO: figure out how to fix the way we are doing our bind
    bindChosenTypes([container, $clonedContainer]);

    // remove parsley classes and error messages on clonedContainer
    $clonedContainer.find('div.form-container-entry-item[data-required=true]').find('ul.parsley-errors-list').remove();
    removeErrorBackground('radio', $clonedContainer);
    removeErrorBackground('checkbox', $clonedContainer);
    removeErrorBackground('checkboxes', $clonedContainer);
    removeUserSuccessClass($clonedContainer);

    // bind maps
    setTimeout(function(){
      // setupDefaultMaps and bindButtons are in maps.js
      // TODO move maps.js into hanuman, make these method calls relative to the $clonedContainer
      setupDefaultMaps();
      bindButtons();
      resetMapButtons($clonedContainer);
    },500)

    // unbind and rebind the pickers
    $(".datepicker").unbind().datepicker();
    $(".timepicki").unbind().timepicki({
      increase_direction: 'up',
      on_change: timepickValidate = function(element) {
        return $(element).parsley().validate();
      }
    });

    // rebind cloudinary
    if ($.fn.cloudinary_fileupload != undefined) {
      $('input.cloudinary-fileupload[type=file]').cloudinary_fileupload()
    }

    bindPhotoUploads()
    bindVideoUploads()
    bindSignatureUploads()
    bindDocumentUploads()
    fillDefaultValues($clonedContainer);

    // resetting parsley required field styling on clonedContainer
    $clonedContainer.find('.parsley-error').removeClass('parsley-error')

    // on edit treat photo, video and doc sections as if new since on edit there is already saved files
    if ($('.survey-edit-mode').length > 0) {
      files = $clonedContainer.find("[data-element-type=file]").find('.custom-cloudinary li a')

      clearFileInputsValuesInEdit(files);

      // the code below is removing an unnecessary input placed in dom by carrierwave for every upload button. If we dont remove this input, we get an error when we submit the form.
      $clonedContainer.find('.file-upload-input-button input[type=hidden]').each(function(i, e){
        if ($(e).attr("name").slice(-4) == "[id]") {
          $(e).remove()
        }
      })
    }

     updateRepeaterIds()
     updateRepeaterControls()

    $clonedContainer.find('.file-upload').each(function() {
      self = this;
      maxPhotos = $(self).find('#max-photos').attr("data-max-photos");
      if (maxPhotos) {
        addedPhotos = $(self).find('.gallery-item').find("img").length;
        console.log(maxPhotos + ' ' + addedPhotos);
        checkMaxPhotos(this, maxPhotos, addedPhotos);
      }
    });

    // bind ConditionalLogic and re-run the logic to hide and show
    cl = new ConditionalLogic;
    cl.findRules($clonedContainer);
  });

  

  function checkMaxPhotos(self, maxPhotos, addedPhotos) {
    if (addedPhotos > maxPhotos) {
      $(self).find('#too-many-photos-alert').attr('style', 'display:block;color:#ff0000;');
      $(self).find('#max-photos-alert').attr('style', 'display:none;');
      $(self).find('.photo-preview').each(function (i) {
        if (i + 1 <= maxPhotos) {
          return true;
        } else {
          $(this).remove();
        }
      });
    }
    if (addedPhotos >= maxPhotos) {
      $(self).find('#too-many-photos-alert').attr('style', 'display:block;color:#ff0000;');
      $(self).find('#max-photos-alert').attr('style', 'display:none;');
      $(self).find('.photo-upload').attr('style', 'display:none;');
    } else {
      $(self).find('#too-many-photos-alert').attr('style', 'display:none;');
      $(self).find('#max-photos-alert').attr('style', 'display:block;');
      $(self).find('.photo-upload').attr('style', 'display:block;');
    }
  }

  function destroyDuplicateChildRepeaters(container) {
    var childRepeaters = $(container).find("> .panel-collapse > .panel-body > .form-container-repeater");

    if (childRepeaters.length !== 0) {
      var questionIds = [];

      childRepeaters.each(function (_, repeater) {
        var questionId = $(repeater).data('question-id');
        if (questionIds.indexOf(questionId) === -1) {
          questionIds.push(questionId);
        }
      });

      questionIds.forEach(function (questionId) {
        var duplicateRepeaters = $(container).find("> .panel-collapse > .panel-body > .form-container-repeater[data-question-id=" + questionId + "]");

        duplicateRepeaters.each(function(index, duplicate) {
          if (index === 0) {
            return;
          } else {
            $(duplicate).remove();
          }
        });
      });

      var newChildRepeaters = $(container).find("> .panel-collapse > .panel-body > .form-container-repeater");

      newChildRepeaters.each(function (_, repeater) {
        destroyDuplicateChildRepeaters(repeater);
      });
    }
  }

  function updateRepeaterControls() {
    var topLevelRepeaterTypes = [];
    $(".form-container-repeater").each(function (_, repeater) {

      var directChildRepeaterTypes = [];
      var $directChildRepeaters = $(repeater).find("> .panel-collapse > .panel-body > .form-container-repeater");
      if ($directChildRepeaters.length) {
        $directChildRepeaters.each(function (_, child) {
          var childRepeaterQuestionId = $(child).data("question-id");
          if(!directChildRepeaterTypes.includes(childRepeaterQuestionId)) {
            directChildRepeaterTypes.push(childRepeaterQuestionId);
          }
        });
      }
      

      if(!$(repeater).parent().parent().parent().first().hasClass("form-container-repeater")) {
        var questionId = $(repeater).data("question-id");
        if(!topLevelRepeaterTypes.includes(questionId)) {
          topLevelRepeaterTypes.push(questionId);
        }
      }

      directChildRepeaterTypes.forEach(function (typeId) {
        var repeaterCount = $(repeater).find(".form-container-repeater[data-question-id=" + typeId + "]").length;
        $(repeater).find(".form-container-repeater[data-question-id=" + typeId + "]").each(function(index, element) {
          var $destroyButton = $(element).find('> .panel-collapse > .panel-body > .form-container-entry-item > .form-group > div > .destroy-form-container-repeater');
          var $duplicateButton = $(element).find('> .panel-collapse > .panel-body > .form-container-entry-item > .form-group > div > .duplicate-form-container-repeater');

          if (index > 0 || repeaterCount > 1) {
            $(element).find(".repeater-count:first").text(" " + (index + 1));
            $destroyButton.show();
          } else {
            $destroyButton.hide();
          }

          if ((index + 1) === repeaterCount) {
            $duplicateButton.show();
          } else {
            $duplicateButton.hide();
          }
        });
      });
    });

    topLevelRepeaterTypes.forEach(function (typeId) {
      var repeaterCount = $(".form-container-repeater[data-question-id=" + typeId + "]").length;
      $(".form-container-repeater[data-question-id=" + typeId + "]").each(function(index, element) {
        var $destroyButton = $(element).find('> .panel-collapse > .panel-body > .form-container-entry-item > .form-group > div > .destroy-form-container-repeater');
        var $duplicateButton = $(element).find('> .panel-collapse > .panel-body > .form-container-entry-item > .form-group > div > .duplicate-form-container-repeater');

        if (index > 0 || repeaterCount > 1) {
          $destroyButton.show();
        } else {
          $destroyButton.hide();
        }

        $(element).find(".repeater-count:first").text(" " + (index + 1));
        
        if (index > 0) {
          // make unique target for collapse
          var question_id = $(element).attr('data-question-id');
          $(element).find('.panel-heading.chevron').attr("data-target", "#collapse_" + question_id + "_" + (index + 1));
          $(element).find('.panel-collapse.in').attr("id", "collapse_" + question_id + "_" + (index + 1));
          console.log($(element).find('.panel-heading.chevron')[0]);
        } else {
          var question_id = $(element).attr('data-question-id');
          $(element).find('.panel-heading.chevron').attr("data-target", "#collapse_" + question_id + "_0");
          $(element).find('.panel-collapse.in').attr("id", "collapse_" + question_id + "_0");
        }

        if (index + 1 === repeaterCount) {
          $duplicateButton.show();
        } else {
          $duplicateButton.hide();
        }
      });
    });
  }

  function updateRepeaterIds() {
    $(".repeater-id").each(function (index, element) {
      $(element).val(index + 1);
    });

    $(".form-container-repeater").each(function (_, repeater) {
      if ($(repeater).parents(".form-container-repeater").length) {
        var parentRepeaterId = $(repeater).parent().closest(".form-container-repeater").find('.repeater-id:first').val();
        $(repeater).find(".parent-repeater-id:first").val(parentRepeaterId);
      }

      var currentRepeaterId = $(repeater).find('.repeater-id:first').val();
      var directObservationChildren = $(repeater).find("> .panel-collapse > .panel-body > .form-container-entry-item[data-question-id]");
      directObservationChildren.each(function (_, observation) {
        $(observation).find(".parent-repeater-id").val(currentRepeaterId);
      });


      var nestedSections = $(repeater).find("> .panel-collapse > .panel-body > .panel:not(.form-container-repeater)");

      nestedSections.each(function (_, section) {
        setSectionParentRepeaterId(currentRepeaterId, section);
      });
    });
  };

  function setSectionParentRepeaterId(repeaterId, section) {
    var directObservationChildren = $(section).find("> .panel-collapse > .panel-body > .form-container-entry-item");
    directObservationChildren.each(function (_, observation) {
      $(observation).find(".parent-repeater-id").val(repeaterId);
    });

    var nestedSections = $(section).find("> .panel-collapse > .panel-body > .panel:not(.form-container-repeater)");


    nestedSections.each(function (_, childSection) {
      setSectionParentRepeaterId(repeaterId, childSection);
    });
  };

  function clearFileInputsValuesInEdit(files){
    while (files.length >= 1) {
      $(files[0]).click();
      files = $clonedContainer.find("[data-element-type=file]").find('.custom-cloudinary li a')
    };
  };

  function clearFilePreviewContainers(container){
    if ($('.survey-edit-mode').length > 0) {
      $($(container).find('.upload-view-mode')).empty();
      $(container).find(".photo-preview").empty()
      $(container).find(".video-preview").empty()
      $(container).find(".document-preview").empty()
      $(container).find(".signature-preview").empty()
    } else {
      $($(container).find('.photo-preview-container')).empty();
      $($(container).find('.video-preview-container')).empty();
      $($(container).find('.document-preview-container')).empty();
      $($(container).find('.signature-preview-container')).empty();
    }

    $($(container)).find('.signature-upload').show();
  };

  function removeErrorBackground(type, $clonedContainer){
    $clonedContainer.find('div.form-container-entry-item[data-element-type='+ type +']').find('div.col-sm-7').removeAttr('style')
  }

  $('.form-container-survey').on('click', ".destroy-form-container-repeater", function(){
    var response = window.confirm('Are you sure you want to delete this observation?')
    var that = this;
    var repeaterId = $(this).closest('.form-container-repeater').find('.repeater-id').val();
    var dataObservationId = $($(this).closest('.form-container-repeater')).attr('data-observation-id');
    // if we have a dataObservationId then the observation has been saved to the DB, thus we need to delete from the DB otherwise just remove from the DOM
    if (response === true) {
      if (dataObservationId) {
        var projectId = window.location.pathname.match(/\/projects\/(\d+)/)[1];
        var surveyId = window.location.pathname.match(/\/surveys\/(\d+)/)[1];
        $.ajax({
          url: "/projects/" + projectId + "/hanuman/surveys/" + surveyId + "/repeater_observation/" + dataObservationId + "/repeater/" + repeaterId,
          method: "Delete"
        }).done(function (response) {
          removeObservationFromDom(that);
        });
      } else {
        removeObservationFromDom(that);
      }
    }

    return false;
  });

  function removeObservationFromDom(observationContainerToDelete) {
    $removeContainer = $(observationContainerToDelete).closest('.form-container-repeater');

    setTimeout(function() {
      $("html, body").animate({
        scrollTop: $removeContainer.offset().top - 500
      }, 1000);
    }, 200);

    $removeContainer.fadeOut(
      2000,
      function() {
          $removeContainer.remove();
          updateRepeaterControls();
          cl = new ConditionalLogic;
          cl.findRules(null);
      }
    );
  };

  function resetMapButtons($clonedContainer){
    var map = $clonedContainer.find('div.form-container-entry-item[data-element-type=map] div.map-buttons')
    $(map).find('a.edit-map').text('Pin a Location on Map');
    $(map).find('a.edit-map').attr('style','display: inline-block;');
    $(map).find('a.cancel-map').attr('style','display: none;');
  };

  function removeUserSuccessClass($clonedContainer){
    var types = ['checkboxes', 'checkbox', 'radio']
    setTimeout(function(){
      types.forEach(function(type){
        $clonedContainer.find('div.form-container-entry-item[data-element-type=' + type + '] .col-sm-7 input').removeClass('user-success');
      })
    }, 2000)
  };

  function stringifyAndResetContainer(containerItems){
    for (var i = 0; i < containerItems.length; i++) {
      stringInput = $(containerItems[i]).prop('outerHTML');
      newInput = $.parseHTML(stringInput);
      $(containerItems[i]).replaceWith(newInput);
    }
  }

  function unbindChosenTypes(element){
    $(element).find(".selectize-taxon-select").each(function () {
      if ($(this)[0].selectize) {
        var data = {};
        data.inputValue = $(this)[0].selectize.getValue();
        data.inputOptions = $(this)[0].selectize.options;

        if (data.inputValue instanceof Array) {
          data.inputText = [];
          var self = this;
          $.each(data.inputValue, function () {
            data.inputText.push($(self)[0].selectize.getItem(this).text());
          });
        } else {
          data.inputText = $(this)[0].selectize.getItem(data.inputValue).text();
        }

        selectizeElements[$(this).attr("id")] = data;

        $(this)[0].selectize.destroy();
      }
    });

    $(element).find(".chosen-multiselect").chosen('destroy');
    $(element).find(".chosen-select").chosen('destroy');
    $(element).find(".bootstrap-checkbox-multiselect").multiselect('destroy');
  }

  function bindChosenTypes(elements){
    $.each(elements, function () {
      $(this).find('.selectize-taxon-select').selectize({
        load: function(query, callback) {
          var dataSourceId = this.$input.data("source");
          var self = this;
          $.ajax({
            url: "/taxa/select_list/" + dataSourceId,
            type: "GET",
            dataType: "json",
            data: {
              query: query
            },
            error: function() {
              callback();
            },
            success: function(res) {
              for (var option in self.options) {
                if ($.inArray(option, self.items) === -1) {
                  self.removeOption(option);
                }
              }
              callback(res.taxa);
            }
          });
        },
        onInitialize: function () {
          var selectId = this.$input.attr("id");
          if (selectId in selectizeElements) {
            var data = selectizeElements[selectId];
            if (data.inputValue instanceof Array) {
              for (var i = 0; i < data.inputValue.length; i++) {
                this.addOption({value: data.inputValue[i], text: data.inputText[i]});
                this.addItem(data.inputValue[i]);
              }
            } else {
              this.addOption({value: data.inputValue, text: data.inputText});
              this.addItem(data.inputValue);
            }
          }
        },
        preload: true,
        create: false,
      });

      $(this).find(".chosen-multiselect").chosen({
        allow_single_deselect: true,
        no_results_text: "No results matched",
        size: "100%",
        single_backstroke_delete: false,
        search_contains: true
      });
      $(this).find(".chosen-select").chosen({
        allow_single_deselect: true,
        no_results_text: "No results matched",
        size: "100%",
        single_backstroke_delete: false,
        search_contains: true
      });

      // Disable calculated fields
      $('.chosen-multiselect[readonly], .chosen-select[readonly]').parent().find('.chosen-container').css({'pointer-events': 'none','opacity': 0.5});

      $(this).find(".bootstrap-checkbox-multiselect").multiselect();
    });
  }

  function updateClonedInputs($clonedRepeater, timeStamp){
    var inputs = $($clonedRepeater).find('input');
    var lastInputIndex = inputs.length - 1;
    var index = 0;
    var parsleySubstrig = Math.random().toString(36).substring(13);
    inputs.each(function(){

      // removing uploaded photos, docs and videos from $clonedContainer
      if ($(inputs[index]).attr('type') == 'file') {
        $(inputs[index]).siblings('.attachinary_container').last().remove();
      }
      if ($(inputs[index]).attr('id')) {
        var idStamp = $(inputs[index]).attr("id").match(/\d+/)[0];
        var newTimeStamp = idStamp.concat(timeStamp);
        $(inputs[index]).attr("id", $(inputs[index]).attr("id").replace(/\d+/, newTimeStamp));
      }
      if ($(inputs[index]).attr('name')) {
        if ($(inputs[index]).attr('name') != "file") {
          var nameStamp = $(inputs[index]).attr("name").match(/\d+/)[0];
          var newTimeStamp = nameStamp.concat(timeStamp);
          $(inputs[index]).attr("name", $(inputs[index]).attr("name").replace(/\d+/, newTimeStamp));
        }else if($(inputs[index]).attr("data-cloudinary-field")) {
          var nameStamp = $(inputs[index]).attr("data-cloudinary-field").match(/\d+/)[0];
          var newTimeStamp = nameStamp.concat(timeStamp);
          $(inputs[index]).attr("data-cloudinary-field", $(inputs[index]).attr("data-cloudinary-field").replace(/\d+/, newTimeStamp));
        }
      }
      if ($(inputs[index]).attr('data-parsley-multiple')) {
        var newTimeStamp = parsleySubstrig.concat(timeStamp);
        $(inputs[index]).attr("data-parsley-multiple", $(inputs[index]).attr("data-parsley-multiple").replace(/(\d+)/, newTimeStamp));
      }
      index ++;
    });
  };

  function updateClonedSelects($clonedRepeater, timeStamp){
    var select = $($clonedRepeater).find('select');
    var index = 0;
    select.each(function(){
      if ($(select[index]).attr('id')) {
        var idStamp = $(select[index]).attr("id").match(/\d+/)[0];
        var newTimeStamp = idStamp.concat(timeStamp);
        $(select[index]).attr("id", $(select[index]).attr("id").replace(/(\d+)/, newTimeStamp));
      }
      if ($(select[index]).attr('name')) {
        var nameStamp = $(select[index]).attr("name").match(/\d+/)[0];
        var newTimeStamp = nameStamp.concat(timeStamp);
        $(select[index]).attr("name", $(select[index]).attr("name").replace(/(\d+)/, newTimeStamp));
      }

      index ++;
    });
  };

  function updateClonedLabels($clonedRepeater, timeStamp){
    var labels = $($clonedRepeater).find('label');
    var index = 0;
    labels.each(function(){
      if ($(labels[index]).attr("for") && $(labels[index]).attr("for").match(/\d+/)) {
        var forStamp = $(labels[index]).attr("for").match(/\d+/)[0];
        var newTimeStamp = forStamp.concat(timeStamp);
        $(labels[index]).attr("for", $(labels[index]).attr("for").replace(/(\d+)/, newTimeStamp));
      }
      index ++
    });
  };

  function updateClonedTextareas($clonedRepeater, timeStamp){
    var textareas = $($clonedRepeater).find('textarea');
    var index = 0;
    textareas.each(function(){
      if ($(textareas[index]).attr('id')) {
        var idStamp = $(textareas[index]).attr("id").match(/\d+/)[0];
        var newTimeStamp = idStamp.concat(timeStamp);
        $(textareas[index]).attr("id", $(textareas[index]).attr("id").replace(/(\d+)/, newTimeStamp));
      }
      if ($(textareas[index]).attr('name')) {
        var nameStamp = $(textareas[index]).attr("name").match(/\d+/)[0];
        var newTimeStamp = nameStamp.concat(timeStamp);
        $(textareas[index]).attr("name", $(textareas[index]).attr("name").replace(/(\d+)/, newTimeStamp));
      }
      $(textareas[index]).val("");
      index ++;
    });
  };

  function updateDom(clonedRepeater, parentRepeater) {

    // setting the timeStamp for the inputs to be updated
    var timeStamp = new Date().getTime();

    // update the parent repeater id input
    // parentRepeaterInput = $(parentRepeater).find('.repeater-id')
    // parentRepeaterInput.each(function(index, element) {
    //   var nameStamp = $(element).attr("name").match(/\d+/)[0];
    //   var nameAttr = $(element).attr("name")
    //   $(element).attr('name', nameAttr.replace(/(\d+)/, nameStamp.concat(timeStamp)))
    // });

    // begin updating all the inputs found in the cloned repeater
    for (var i = 0; i < clonedRepeater.length; i++) {
      $($(clonedRepeater[i]).find('.latlong')).attr('id', "map".concat(timeStamp));
      updateClonedInputs(clonedRepeater[i], timeStamp);
      updateClonedLabels(clonedRepeater[i], timeStamp);
      updateClonedSelects(clonedRepeater[i], timeStamp);
      updateClonedTextareas(clonedRepeater[i], timeStamp);
      $($(clonedRepeater[i]).find('.chosen-container')).attr("id", "survey_observations_attributes_" + timeStamp + "_answer_chosen");
      timeStamp = new Date().getTime();
    };
  };

  function clearValues(clonedRepeater){
    for (var i = 0; i < clonedRepeater.length; i++) {
      $(clonedRepeater[i]).find("input[type=date]").val("");
      $(clonedRepeater[i]).find("input[type=email]").val("");
      $(clonedRepeater[i]).find("input[type=number]").val("");
      $(clonedRepeater[i]).find("input[type=tel]").val("");
      $(clonedRepeater[i]).find("input[type=time]").val("");
      textFields = $(clonedRepeater[i]).find(":text").val("");
      textAreas = $(clonedRepeater[i]).find("textarea").val("");
      // un-select dropdown
      selects = $(clonedRepeater[i]).find("select");
      $(selects).each(function() {
        if ($(this).hasClass('selectized')) {
          if ($(this)[0].selectize) {
            console.log($(this)[0].selectize.items)
          }
        }
        $(this).val("");

        // if we don't add please select at this point the dropdown will show blank with no prompt
        if ($(this).find('option:contains("Please select")').length < 1) {
          $(this).prepend("<option value>Please select</option>");
        }

      });
      multiselects = $(clonedRepeater[i]).find("select[multiple]");
      $(multiselects).each(function() {
        $('#' + $(this).attr('id') + ' option:selected').removeAttr("selected");
        if ($(this).hasClass('chosen-multiselect')) {
          $(this).trigger("chosen:updated");
        }
      });
      // uncheck all checkboxes
      checkboxes = $(clonedRepeater[i]).find(":checkbox");
      $(checkboxes).each(function() {
        $(this).prop('checked', false);
      });
      // un-select radio buttons
      radiobuttons = $(clonedRepeater[i]).find(":radio");
      $(radiobuttons).each(function() {
        $(this).prop('checked', false);
      });

      // trigger onchange event which is needed for embedded conditional logic
      // Commented this line of code below beacause When adding a repeater, it was clearing values of CL text field of first repeater. IT doesnt seem to be nessesary.
      // $(clonedRepeater[i]).find('.form-control').trigger('change');
    };
  };

  // the same code that runs in hanuman-conditional-logic.js to populate the default values
  function fillDefaultValues(container) {
    textFields = container.find(":text");
    textFields.each(function() {
      if($(this).attr("data-default-answer") && $(this).data("default-answer") != "null") {
        $(this).val($(this).data("default-answer"));
      } else {
        $(this).val("");
      }
    });

    textAreas = container.find("textarea");
    textAreas.each(function() {
      if($(this).attr("data-default-answer") && $(this).data("default-answer") != "null") {
        $(this).val($(this).data("default-answer"));
      } else {
        $(this).val("");
      }
    });

    // un-select dropdown
    selects = container.find("select");
    selects.each(function() {
      if($(this).attr("data-default-answer") && $(this).data("default-answer") != "null") {
        $(this).val($(this).data("default-answer"));
      } else {
        $(this).val("");
      }
      if($(this).hasClass('chosen')) {
        $(this).trigger("chosen:updated");
      }
    });

    // uncheck all checkboxes
    checkboxes = container.find(":checkbox");
    checkboxes.each(function() {
      if($(this).attr("data-default-answer") && $(this).data("default-answer") == "true") {
        $(this).prop('checked', true);
      } else {
        $(this).prop('checked', false);
      }
    });

    // un-select radio buttons
    radiobuttons = container.find(":radio");
    radiobuttons.each(function() {
      if($(this).attr("data-default-answer") && $(this).data("default-answer") != "null" && $(this).data("label-value") == $(this).data("default-answer")) {
        $(this).prop('checked', true);
      } else {
        $(this).prop('checked', false);
      }
    });

    multiselects = container.find("select[multiple]")
    multiselects.each(function() {
      id = $(this).attr('id');
      $('#' + id + ' option:selected').removeAttr("selected");
      if($(this).hasClass('chosen-multiselect')) {
        $(this).trigger("chosen:updated");
      }
    });
  }

});
