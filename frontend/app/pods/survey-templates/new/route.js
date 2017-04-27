import Ember from 'ember';
import SurveyTemplateSaveRoute from 'frontend/mixins/survey-template-save-route';

export default Ember.Route.extend(SurveyTemplateSaveRoute, {
  model() {
    return this.store.createRecord('survey-template');
  }
});