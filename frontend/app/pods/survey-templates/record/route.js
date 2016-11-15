import Ember from 'ember';

const { run, isPresent, isBlank, inject } = Ember;

export default Ember.Route.extend({
  notify: inject.service('notify'),
  setupController(controller, model) {
    this._super(controller, model);
    // Progress bar indicators
    let i = 0,
        p = 0,
        surveyTemplate = model,
        total = surveyTemplate.get('questions.length');
    if(total === 0){
      controller.set('isLoadingQuestions', false);
    }else{
      surveyTemplate.hasMany('questions').ids().forEach((questionId) => {
        if(!questionId){
          i += 1;
          return;
        }
        this.store.findRecord('question', questionId).then(function() {
          let pp = p;
          i += 1;
          p = (((i * 10 / total) - ((i * 10 / total) %0.5)));
          if(pp !== p){
            controller.set('loadingProgress', ((p * 10) + 5));
          }
          if((i+1) >= total){
            run.next(this, function() {
              controller.set('isLoadingQuestions', false);
            });
          }
        });
      });
    }
  },

  _checkAncestryConsistency(questions){
    questions.forEach(function(question) {
      if(isPresent(question.get('parentId'))) {
        let parentId = question.get('parentId'),
            parent = questions.findBy('id', parentId),
            sortOrder = question.get('sortOrder');
        if(isBlank(parent)) { return; }
        let questionToAskDown = questions.findBy('sortOrder', question.get('sortOrder') + 1);
        if(parent.get('sortOrder') > sortOrder){
          question.set('parentId', null);
          if(isPresent(questionToAskDown)){
            question.set('parentId', questionToAskDown.get('parentId'));
            question.save().then(()=>{
              question.reload();
            });
          }
        }
      }
    });
  },

  actions:{
    reorderQuestions(questions){
      this.send('updateSortOrder',questions);
    },
    updateSortOrder(questions){
      questions.forEach((question, index) => {
        let oldSortOrder = question.get('sortOrder'),
            newSortOrder = index + 1;
        if(oldSortOrder !== newSortOrder){
          question.set('sortOrder', newSortOrder);
          question.save();
        }
      });
      this._checkAncestryConsistency(questions);
    },
    duplicate(){
      let indexController = this.controllerFor('survey-templates.record.index');
      let surveyTemplate = this.currentModel;
      indexController.send('toggleDuplicateLoading');
      surveyTemplate.duplicate().then((duplicateReponse) => {
        this.transitionTo('survey_templates.record', duplicateReponse.survey_template.id);
        run.later(this ,()=> { this.get('notify').success('Survey Template successfully duplicated.'); }, 1000);
      }).catch((error) => {
        console.log(error);
        this.get('notify').alert('There was an error trying to duplicate this Survey Template');
      }).finally(() => {
        run.later(this ,()=> { indexController.send('toggleDuplicateLoading'); }, 1500);
      });
    }
  }
});
