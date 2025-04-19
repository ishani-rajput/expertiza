require 'rails_helper'

RSpec.describe QuestionnaireHelper, type: :helper do
  require 'rails_helper'

  describe '.adjust_advice_size' do
    let(:questionnaire) { double('Questionnaire', min_question_score: 1, max_question_score: 3) }
    let(:question) { double('ScoredQuestion', id: 101, question_advices: []) }

    before do
      allow(question).to receive(:is_a?).with(ScoredQuestion).and_return(true)
    end

    context 'when question is not a ScoredQuestion' do
      it 'does not perform any operations' do
        non_scored_question = double('Question')
        expect(non_scored_question).to receive(:is_a?).with(ScoredQuestion).and_return(false)
        expect(QuestionAdvice).not_to receive(:delete)
        QuestionnaireHelper.adjust_advice_size(questionnaire, non_scored_question)
      end
    end

    context 'when question is a ScoredQuestion' do
      it 'deletes advice entries outside valid score range' do
        expect(QuestionAdvice).to receive(:delete).with(
          ['question_id = ? AND (score > ? OR score < ?)', question.id, 3, 1]
        )
        allow(QuestionAdvice).to receive(:where).and_return([])

        QuestionnaireHelper.adjust_advice_size(questionnaire, question)
      end

      it 'adds missing advice and deletes duplicates' do
        # Simulate score range 1..3
        (1..3).each do |score|
          qas = double('ActiveRecord::Relation', first: nil, size: 0)
          allow(QuestionAdvice).to receive(:where).with('question_id = ? AND score = ?', question.id, score).and_return(qas)
          expect(question.question_advices).to receive(:<<).with(instance_of(QuestionAdvice))
        end

        allow(QuestionAdvice).to receive(:delete)

        QuestionnaireHelper.adjust_advice_size(questionnaire, question)
      end
    end

    context 'when valid advice exists for all scores in range' do
      it 'does not create or delete any advice' do
        (1..3).each do |score|
          advice = double('QuestionAdvice')
          qas = [advice]
          allow(QuestionAdvice).to receive(:where).with('question_id = ? AND score = ?', question.id, score).and_return(qas)
          expect(question.question_advices).not_to receive(:<<)
          expect(QuestionAdvice).not_to receive(:delete).with(['question_id = ? AND score = ?', question.id, score])
        end
    
        allow(QuestionAdvice).to receive(:delete).with(any_args) # for the outer delete, still expectable
        QuestionnaireHelper.adjust_advice_size(questionnaire, question)
      end
    end
    
    context 'when multiple advice entries exist for a score' do
      it 'deletes duplicate entries' do
        (1..3).each do |score|
          advice = double('QuestionAdvice')
          qas = [advice, advice]
          allow(QuestionAdvice).to receive(:where).with('question_id = ? AND score = ?', question.id, score).and_return(qas)
          expect(QuestionAdvice).to receive(:delete).with(['question_id = ? AND score = ?', question.id, score])
        end
    
        allow(question.question_advices).to receive(:<<)
        allow(QuestionAdvice).to receive(:delete).with(['question_id = ? AND (score > ? OR score < ?)', question.id, 3, 1])
        QuestionnaireHelper.adjust_advice_size(questionnaire, question)
      end
    end
    
    context 'when some scores are missing advice' do
      it 'creates only missing advice entries' do
        (1..3).each do |score|
          if score == 2
            # Simulate missing advice
            allow(QuestionAdvice).to receive(:where)
              .with('question_id = ? AND score = ?', question.id, score)
              .and_return([])
    
            # Expect creation only for missing score
            expect(question.question_advices).to receive(:<<)
              .with(have_attributes(score: score))
          else
            advice = double('QuestionAdvice')
            allow(QuestionAdvice).to receive(:where)
              .with('question_id = ? AND score = ?', question.id, score)
              .and_return([advice])
    
            # Expect NO creation for scores that already have advice
            expect(question.question_advices).not_to receive(:<<)
              .with(have_attributes(score: score))
          end
        end
    
        allow(QuestionAdvice).to receive(:delete).with(any_args)
    
        QuestionnaireHelper.adjust_advice_size(questionnaire, question)
      end
    end       
  end
end