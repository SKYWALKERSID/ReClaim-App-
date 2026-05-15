import { AnalyticsService } from './analytics.service';
import { db } from '../db';
import { users, userStats, activeGoals, habits } from '../db/schema';
import { eq, desc } from 'drizzle-orm';

export interface CoachContext {
    user: {
        name: string;
        timezone: string;
        joined_days_ago: number;
        current_streak: number;
        longest_streak: number;
    };
    goals: any[];
    habits: any[];
    weekly_summary: any;
    missed_habits_last_3_days: any[];
    upcoming_milestones: any[];
    time_of_day: string;
    day_of_week: string;
    mode: string;
}

export class CoachService {
    private analytics = new AnalyticsService();

    async getCoachContext(userId: string, mode: string = 'quick_checkin'): Promise<CoachContext> {
        const user = await db.query.users.findFirst({
            where: eq(users.id, userId)
        });

        const stats = await db.query.userStats.findFirst({
            where: eq(userStats.userId, userId)
        });

        const goals = await db.query.activeGoals.findMany({
            where: eq(activeGoals.userId, userId)
        });

        const userHabits = await db.query.habits.findMany({
            where: eq(habits.userId, userId)
        });

        const now = new Date();
        const hour = now.getHours();
        let timeOfDay = "night";
        if (hour >= 5 && hour < 12) timeOfDay = "morning";
        else if (hour >= 12 && hour < 17) timeOfDay = "afternoon";
        else if (hour >= 17 && hour < 21) timeOfDay = "evening";

        const days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
        const dayOfWeek = days[now.getDay()];

        return {
            user: {
                name: user?.name || "User",
                timezone: user?.timezone || "UTC",
                joined_days_ago: user?.createdAt ? Math.floor((now.getTime() - new Date(user.createdAt).getTime()) / (1000 * 60 * 60 * 24)) : 0,
                current_streak: stats?.currentStreak || 0,
                longest_streak: stats?.longestStreak || 0,
            },
            goals: goals.map(g => ({ name: g.name, target: g.targetDate, progress: g.progress })),
            habits: userHabits.map(h => ({ name: h.name, rate: h.completionRate })),
            weekly_summary: await this.analytics.getWeeklyCompletion(userId),
            missed_habits_last_3_days: [], // Mock or fetch from logs
            upcoming_milestones: [],
            time_of_day: timeOfDay,
            day_of_week: dayOfWeek,
            mode: mode
        };
    }

    getSystemPrompt(context: CoachContext): string {
        return `
# System Prompt: AI Habit Coach & Goal Setting Assistant

## Role & Identity
You are an empathetic, science-backed habit coach embedded inside a personal productivity app. Your name is ReClaim Coach. You blend the frameworks of behavioral psychology (BJ Fogg's Tiny Habits, James Clear's Atomic Habits) with personalized goal architecture to help users build lasting habits and achieve meaningful goals.

## Context
User: ${context.user.name}
Streak: ${context.user.current_streak} days
Time: ${context.time_of_day} (${context.day_of_week})
Goals: ${JSON.stringify(context.goals)}
Habits: ${JSON.stringify(context.habits)}
Mode: ${context.mode}

## Core Capabilities
1. Goal Setting & Decomposition (SMART goals)
2. Habit Design (Cue -> Routine -> Reward)
3. Daily Check-ins & Motivation
4. Streak & Progress Coaching
5. Accountability & Reflection

## Behavioral Guidelines
- Be warm, direct, and conversational
- Lead with empathy, follow with strategy
- Give one clear next step at the end of every coaching session
- Use bold for key insights
- Keep paragraphs to 2–3 sentences max
- Use bullet lists only for action steps or options
- End every interaction with a single, clear Next Step or Question to Reflect On
- Emoji use: minimal, purposeful (✅, 🎯, 🔥)

## Ethics
- Never diagnose mental health conditions
- Do not create dependency
- Respect user autonomy
`;
    }
}
