import { GoogleGenerativeAI } from "@google/generative-ai";

const API_KEY = import.meta.env.VITE_GEMINI_API_KEY || "";
const genAI = new GoogleGenerativeAI(API_KEY);

export interface AiFeedback {
  explanation: string;
  isHindi?: boolean;
}

export class AiService {
  private model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });

  async getFeedback(
    question: string,
    options: string[],
    correctAnswer: string,
    userAnswer: string,
    imageDescription?: string,
    forceHindi: boolean = false
  ): Promise<AiFeedback> {
    if (!API_KEY) {
      return {
        explanation: forceHindi 
          ? "AI सेवा अभी उपलब्ध नहीं है। कृपया बाद में प्रयास करें।" 
          : "AI service is currently unavailable. Please try again later."
      };
    }

    const prompt = `
      You are an AI teacher named Saathi, helping a child learn.
      Task: Explain why the user's answer is wrong or provide encouragement if they were close.
      
      Question: ${question}
      Options: ${options.join(", ")}
      Correct Answer: ${correctAnswer}
      User's Answer: ${userAnswer}
      ${imageDescription ? `Image contains: ${imageDescription}` : ""}

      Language: ${forceHindi ? "Hindi" : "English"}

      Requirements:
      1. Keep it simple and encouraging (3-4 sentences).
      2. Use JSON format: {"explanation": "your explanation here"}
      3. For children (age 4-10).
      4. If Hindi is requested, use Devanagari script.
    `;

    try {
      const result = await this.model.generateContent(prompt);
      const response = await result.response;
      const text = response.text();
      
      // Attempt to parse JSON from the response
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const data = JSON.parse(jsonMatch[0]);
        return {
          explanation: data.explanation || text,
          isHindi: forceHindi
        };
      }
      
      return { explanation: text, isHindi: forceHindi };
    } catch (error) {
      console.error("AI Service Error:", error);
      return {
        explanation: forceHindi
          ? "माफ़ करें, मैं अभी विश्लेषण नहीं कर पा रहा हूँ।"
          : "Sorry, I couldn't analyze the answer right now.",
        isHindi: forceHindi
      };
    }
  }
}

export const aiService = new AiService();
