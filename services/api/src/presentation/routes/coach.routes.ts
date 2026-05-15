import { Router } from 'express';
import { chatWithCoach } from '../controllers/coachController';
import { authenticate } from '../middleware/auth'; // Assuming auth middleware exists

const router = Router();

router.post('/chat', authenticate, chatWithCoach);

export default router;
