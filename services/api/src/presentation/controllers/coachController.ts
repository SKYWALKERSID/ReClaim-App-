import { Request, Response } from 'express';
import { CoachService } from '../../services/coach.service';

const coachService = new CoachService();

export const chatWithCoach = async (req: Request, res: Response) => {
    try {
        const userId = req.user?.id;
        const { message, mode } = req.body;

        if (!userId) return res.status(401).json({ error: 'Unauthorized' });

        const context = await coachService.getCoachContext(userId, mode);
        const systemPrompt = coachService.getSystemPrompt(context);

        // In a real implementation, you would call an LLM API here (e.g., Gemini, OpenAI)
        // const response = await callLLM(systemPrompt, message);
        
        // Mocking LLM response for now
        const response = `Hey ${context.user.name}, I see you're on a **${context.user.current_streak} day streak** 🔥. Let's keep that momentum! What's the one thing you want to focus on today?`;

        res.json({
            message: response,
            context: context // Optional: for debugging or UI enrichment
        });
    } catch (error) {
        console.error('Coach Chat Error:', error);
        res.status(500).json({ error: 'Internal Server Error' });
    }
};
