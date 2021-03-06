import { test } from 'qunit';
import moduleForAcceptance from 'frontend/tests/helpers/module-for-acceptance';

let surveyTemplate, questions;

moduleForAcceptance('Acceptance | survey template', {
  beforeEach() {
    server.loadFixtures();
    surveyTemplate = server.create('survey-template');
    questions = server.createList('question', 5, { surveyTemplate });
  }
});

test('visiting /survey_templates/:id', async function(assert) {
  assert.expect(1);
  await visit(`/survey_templates/${surveyTemplate.id}`);
  assert.equal(currentURL(), `/survey_templates/${surveyTemplate.id}`);
});

test('displaying survey template info', async function(assert) {
  assert.expect(2);
  await visit(`/survey_templates/${surveyTemplate.id}`);
  assert.equal(
    surveyTemplate.name,
    find('[data-test="surveyTemplate.name"]')
      .text()
      .trim()
  );
  assert.equal(
    surveyTemplate.status,
    find('[data-test="surveyTemplate.status"]')
      .text()
      .trim()
  );
});

test('listing questions', async function(assert) {
  await visit(`/survey_templates/${surveyTemplate.id}`);
  for (let question of questions) {
    assert.equal(
      question.question_text,
      find(`[data-question-id="${question.id}"] [data-test="question.questionText"]`)
        .text()
        .trim()
    );
  }
});

test('deleting a survey template', async function(assert) {
  assert.expect(1);
  await visit(`/survey_templates/${surveyTemplate.id}`);
  await click('[data-test="delete-survey-link"]');
  assert.equal(server.db.surveyTemplates.length, 0);
});

test('editing a survey template', async function(assert) {
  assert.expect(3);
  await visit(`/survey_templates/${surveyTemplate.id}`);
  await click('[data-test="edit-survey-link"]');
  assert.equal(currentURL(), `/survey_templates/${surveyTemplate.id}/edit`);
  await fillIn('[data-test="surveyTemplate.name"]', 'Yo te vi salir campeón del continente');
  await click('[data-test="save-survey-template-link"]');
  surveyTemplate = server.db.surveyTemplates.find(surveyTemplate.id);
  assert.equal(surveyTemplate.name, 'Yo te vi salir campeón del continente');
  assert.equal(currentURL(), `/survey_templates/${surveyTemplate.id}`);
});

test('creating a survey template', async function(assert) {
  assert.expect(4);
  await visit('/survey_templates/new');
  assert.equal(currentURL(), '/survey_templates/new');
  fillIn('[data-test="surveyTemplate.name"]', 'Yo te vi salir campeón del continente 2 veces');
  fillIn('[data-test="surveyTemplate.surveyType"]', 'campeon');
  await click('[data-test="save-survey-template-link"]');
  surveyTemplate = server.schema.surveyTemplates
    .all()
    .models.slice(-1)
    .pop();
  assert.equal(surveyTemplate.name, 'Yo te vi salir campeón del continente 2 veces');
  assert.equal(surveyTemplate.surveyType, 'campeon');
  assert.equal(currentURL(), `/survey_templates/${surveyTemplate.id}`);
});
