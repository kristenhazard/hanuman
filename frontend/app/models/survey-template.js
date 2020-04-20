import Model from 'ember-data/model';
import attr from 'ember-data/attr';
import { hasMany } from 'ember-data/relationships';
import { memberAction } from 'ember-api-actions';
import { filterBy } from '@ember/object/computed';

import Validator from './../mixins/model-validator';

// Constants
const STATUSES = ['draft', 'active', 'inactive'];

const SurveyTemplate = Model.extend(Validator, {
  // Attributes
  name: attr('string'),
  status: attr('string', { defaultValue: 'draft' }),
  surveyType: attr('string'),
  fullyEditable: attr('boolean'),
  duplicatorLabel: attr('string'),
  namePlusVersion: attr('string'),
  // Wildnote specific data
  lock: attr('boolean'),
  version: attr('string'),
  description: attr('string'),
  // Custom hack for Wildnote
  organizationId: attr('number'),
  surveyTemplateExportTypeId: attr('number'),

  // Relations
  questions: hasMany('question'),
  // Computed
  questionsNotNew: filterBy('questions', 'isNew', false),
  questionsNotDeleted: filterBy('questionsNotNew', 'isDeleted', false),
  filteredQuestions: filterBy('questionsNotDeleted', 'ancestryCollapsed', false),

  // Custom actions
  duplicate: memberAction({ path: 'duplicate', type: 'post' }),
  resortQuestions: memberAction({ path: 'resort_questions', type: 'patch' }),
  checkTemplate: memberAction({ path: 'check_template', type: 'get' }),


  // Validations
  validations: {
    name: {
      presence: true
    },
    status: {
      inclusion: {
        in: STATUSES
      }
    }
  },

  toggleEditableWarning() {
    let $warning = $('.editable-warning');
    $warning.toggle();
  }


});

SurveyTemplate.reopenClass({
  STATUSES
});

export default SurveyTemplate;
