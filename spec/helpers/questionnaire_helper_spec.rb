require 'rails_helper'

RSpec.describe QuestionnaireHelper, type: :helper do
  describe '.adjust_advice_size' do
    let(:questionnaire) { double('Questionnaire', min_question_score: 1, max_question_score: 3) }
    let(:question) { double('ScoredQuestion', id: 1, question_advices: []) }

    before do
      allow(question).to receive(:is_a?).with(ScoredQuestion).and_return(true)
    end

    context 'when question is not a ScoredQuestion' do
      it 'does not make any changes' do
        non_scored_question = double('Question')
        expect(non_scored_question).to receive(:is_a?).with(ScoredQuestion).and_return(false)
        expect(QuestionAdvice).not_to receive(:delete)
        QuestionnaireHelper.adjust_advice_size(questionnaire, non_scored_question)
      end
    end

    context 'when question is a ScoredQuestion' do
      it 'removes QuestionAdvice entries outside the valid score range' do
        expect(QuestionAdvice).to receive(:delete).with(['question_id = ? AND (score > ? OR score < ?)', question.id, 3, 1])
        allow(QuestionAdvice).to receive(:where).and_return([])

        QuestionnaireHelper.adjust_advice_size(questionnaire, question)
      end

      it 'creates missing advice and removes duplicates' do
        (1..3).each do |score|
          fake_qas = double('ActiveRecord::Relation', first: nil, size: 0)
          allow(QuestionAdvice).to receive(:where).with('question_id = ? AND score = ?', question.id, score).and_return(fake_qas)
          expect(question.question_advices).to receive(:<<).with(instance_of(QuestionAdvice))
        end
        allow(QuestionAdvice).to receive(:delete)

        QuestionnaireHelper.adjust_advice_size(questionnaire, question)
      end
    end
  end

  describe '#update_questionnaire_questions' do
    controller(ApplicationController) do
      include QuestionnaireHelper
    end

    before do
      @question1 = double('Question', id: 1)
      @question2 = double('Question', id: 2)

      allow(Question).to receive(:find).with("1").and_return(@question1)
      allow(Question).to receive(:find).with("2").and_return(@question2)
    end

    it 'returns early if params[:question] is nil' do
      allow(controller).to receive(:params).and_return({})
      expect(@question1).not_to receive(:save)
      controller.update_questionnaire_questions
    end

    it 'updates changed attributes and saves the question' do
      allow(@question1).to receive(:send).with('txt').and_return('Old text')
      allow(@question1).to receive(:send).with('weight').and_return('1')
      expect(@question1).to receive(:send).with('txt=', 'Updated question text')
      expect(@question1).to receive(:send).with('weight=', '2')
      expect(@question1).to receive(:save)

      allow(@question2).to receive(:send).with('txt').and_return('Another text')
      allow(@question2).to receive(:send).with('weight').and_return('1')
      expect(@question2).not_to receive(:send).with('txt=', anything)
      expect(@question2).not_to receive(:send).with('weight=', anything)
      expect(@question2).to receive(:save)

      allow(controller).to receive(:params).and_return({
        question: {
          "1" => { "txt" => "Updated question text", "weight" => "2" },
          "2" => { "txt" => "Another text", "weight" => "1" }
        }
      })

      controller.update_questionnaire_questions
    end
  end

  describe '#questionnaire_factory' do
    controller(ApplicationController) do
      include QuestionnaireHelper
    end

    before do
      stub_const("ReviewQuestionnaire", Class.new)
      stub_const("SurveyQuestionnaire", Class.new)
      controller.class.const_set("QUESTIONNAIRE_MAP", {
        'ReviewQuestionnaire' => ReviewQuestionnaire,
        'SurveyQuestionnaire' => SurveyQuestionnaire
      })
    end

    it 'returns the correct questionnaire instance for a valid type' do
      instance = controller.questionnaire_factory('ReviewQuestionnaire')
      expect(instance).to be_a(ReviewQuestionnaire)
    end

    it 'sets flash error and returns nil for an invalid type' do
      flash = {}
      allow(controller).to receive(:flash).and_return(flash)

      result = controller.questionnaire_factory('InvalidType')
      expect(result).to be_nil
      expect(flash[:error]).to eq('Error: Undefined Questionnaire')
    end

    it 'handles nil or empty type string' do
      flash = {}
      allow(controller).to receive(:flash).and_return(flash)

      result = controller.questionnaire_factory(nil)
      expect(result).to be_nil
      expect(flash[:error]).to eq('Error: Undefined Questionnaire')
    end
  end
end