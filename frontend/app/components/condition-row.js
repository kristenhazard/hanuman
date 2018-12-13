import Component from '@ember/component';
import { alias } from '@ember/object/computed';
import { computed } from '@ember/object';
import { isNone, isBlank } from '@ember/utils';
import { inject as service } from '@ember/service';
import { task } from 'ember-concurrency';

import config from 'frontend/config/environment';

const testing = config.environment === 'test';

import Condition from '../models/condition';

export default Component.extend({
  ajax: service(),
  for: alias('condition'),
  tagName: 'tr',
  attributeBindings: ['condition.id:data-condition-id'],
  classNameBindings: ['isNewCondition:no-hover'],
  isEditingCondition: false,

  loadLocations: task(function*() {
    let projectId;
    if (window.location.href.indexOf('/projects/') !== -1) {
      projectId = window.location.href.split('/')[6];
    }
    if (projectId || testing) {
      let response = yield this.ajax.request(`/locations?project_id=${projectId}`);
      this.set('locations', response.locations);
    } else {
      this.set('locations', []);
    }
  }),

  loadDataSources: task(function*() {
    let currentQuestion = this.get('currentQuestion');
    let dataSourceId = currentQuestion.belongsTo('dataSource').id();
    if (dataSourceId) {
      let response = yield this.ajax.request(`/data_sources/${dataSourceId}/data_source_taxon_mappings`);
      this.set('dataSources', response.data_sources);
    } else {
      this.set('dataSources', []);
    }
  }),

  operators: computed('currentQuestion', function() {
    let answerType = this.get('currentQuestion.answerType');
    if (['checkboxes', 'multiselect'].includes(answerType.get('elementType'))) {
      return Condition.OPERATORS.filter(function(op) {
        return op.includes('equal');
      });
    } else {
      return Condition.OPERATORS;
    }
  }),

  currentQuestion: computed('condition.questionId', function() {
    return this.get('questions').findBy('id', this.get('condition.questionId'));
  }),

  questionAnswerChoices: computed('currentQuestion', function() {
    return this.get('currentQuestion.answerChoices');
  }),

  useDropDownAnswerSelect: computed('currentQuestion', 'condition.operator', function() {
    let currentQuestion = this.get('currentQuestion');
    let conditionOperator = this.get('condition.operator');
    let value =
      conditionOperator !== 'contains' &&
      currentQuestion &&
      (currentQuestion.hasMany('answerChoices').ids().length > 1 ||
        currentQuestion.isLocationSelect ||
        currentQuestion.isTaxonType);
    if (currentQuestion.isLocationSelect && isBlank(this.locations)) {
      this.loadLocations.perform();
    }
    if (currentQuestion.isTaxonType) {
      this.loadDataSources.perform();
    }
    return value;
  }),

  setNewCondition() {
    let rule = this.rule ? this.rule : this.get('question.visibilityRule');
    let condition = this.get('question').store.createRecord('condition', {
      questionId: this.get('questions.firstObject.id'),
      rule
    });
    this.set('condition', condition);
  },

  actions: {
    toggleForm() {
      this.toggleProperty('isEditingCondition');
      if (isNone(this.get('condition'))) {
        this.setNewCondition();
      }
    },

    save() {
      let condition = this.get('condition');
      let rule = this.rule ? this.rule : this.get('question.visibilityRule');

      // Strip any trailing spaces off of a condition answer before saving it.
      let answer = condition.get('answer') || '';
      condition.set('answer', answer.trim());

      if (condition.validate()) {
        condition.set('rule', rule);
        this.saveTask.perform(condition, rule);
        if (this.get('isNewCondition')) {
          this.set('condition', null);
        }
        this.send('toggleForm');
      }
    },

    delete() {
      let condition = this.get('condition');
      let rule = this.rule ? this.rule : this.get('question.visibilityRule');
      this.removeTask.perform(condition, rule);
    },
    setConditionOperator(operator) {
      this.set('condition.operator', operator);
    },
    setConditionQuestion(questionId) {
      this.set('condition.questionId', questionId);
    },
    setConditionAnswer(answer) {
      this.set('condition.answer', answer);
    }
  }
});
