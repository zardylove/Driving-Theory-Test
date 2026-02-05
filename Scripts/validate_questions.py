#!/usr/bin/env python3
"""
UK Driving Theory Test - Question Validation Script
Validates questions_master.csv and converts to questions.json

CRITICAL: This script must match your Swift Question model EXACTLY
"""

import csv
import json
import sys
from collections import Counter, defaultdict
from typing import List, Dict, Set, Tuple

# Valid categories (must match app exactly)
VALID_CATEGORIES = {
    'alertness',
    'attitudeToOtherRoadUsers',
    'safetyAndYourVehicle',
    'safetyMargins',
    'hazardAwareness',
    'vulnerableRoadUsers',
    'otherTypesOfVehicle',
    'vehicleHandling',
    'motorwayRules',
    'rulesOfTheRoad',
    'roadAndTrafficSigns',
    'essentialDocuments',
    'incidents',
    'vehicleLoading'
}

VALID_DIFFICULTIES = {'easy', 'medium', 'hard'}

class ValidationError:
    def __init__(self, question_id: str, error: str, severity: str = 'error'):
        self.question_id = question_id
        self.error = error
        self.severity = severity  # 'error', 'warning', 'info'
    
    def __str__(self):
        icon = '❌' if self.severity == 'error' else '⚠️' if self.severity == 'warning' else 'ℹ️'
        return f"{icon} [{self.question_id}] {self.error}"

def validate_questions(csv_file: str) -> tuple[List[Dict], List[ValidationError]]:
    """Validate CSV and return questions + errors"""
    questions = []
    errors = []
    seen_ids: Set[str] = set()
    row_num = 0
    
    try:
        with open(csv_file, 'r', encoding='utf-8') as file:
            csv_reader = csv.DictReader(file)
            
            for row in csv_reader:
                row_num += 1
                
                # Skip if not Ready status
                if row.get('Status', '').strip() != 'Ready':
                    continue
                
                question_id = row.get('ID', '').strip()
                
                # Validate ID
                if not question_id:
                    errors.append(ValidationError(f"Row {row_num}", "Missing ID", 'error'))
                    continue
                
                # Check for duplicate IDs
                if question_id in seen_ids:
                    errors.append(ValidationError(question_id, "Duplicate ID", 'error'))
                    continue
                seen_ids.add(question_id)
                
                # Validate category
                category = row.get('Category', '').strip()
                if category not in VALID_CATEGORIES:
                    errors.append(ValidationError(
                        question_id, 
                        f"Invalid category '{category}'. Must be one of: {', '.join(sorted(VALID_CATEGORIES))}", 
                        'error'
                    ))
                
                # Validate difficulty
                difficulty = row.get('Difficulty', '').strip().lower()
                if difficulty not in VALID_DIFFICULTIES:
                    errors.append(ValidationError(
                        question_id,
                        f"Invalid difficulty '{difficulty}'. Must be: easy, medium, or hard",
                        'error'
                    ))
                
                # Validate question text
                question_text = row.get('Question', '').strip()
                if not question_text:
                    errors.append(ValidationError(question_id, "Empty question text", 'error'))
                elif len(question_text) < 10:
                    errors.append(ValidationError(question_id, "Question text too short (< 10 chars)", 'warning'))
                elif len(question_text) > 300:
                    errors.append(ValidationError(question_id, f"Question text too long ({len(question_text)} chars)", 'warning'))
                
                # Validate options (must have exactly 4)
                options = [
                    row.get('Option_A', '').strip(),
                    row.get('Option_B', '').strip(),
                    row.get('Option_C', '').strip(),
                    row.get('Option_D', '').strip()
                ]
                
                if not all(options):
                    errors.append(ValidationError(question_id, "Missing one or more options (need exactly 4)", 'error'))
                
                # Check for duplicate options
                if len(set(options)) != len(options):
                    errors.append(ValidationError(question_id, "Duplicate options detected", 'warning'))
                
                # Validate correct answer
                correct_answer = row.get('Correct_Answer', '').strip().upper()
                if correct_answer not in ['A', 'B', 'C', 'D']:
                    errors.append(ValidationError(
                        question_id,
                        f"Invalid correct answer '{correct_answer}'. Must be A, B, C, or D",
                        'error'
                    ))
                
                # Convert correct answer to index
                answer_map = {'A': 0, 'B': 1, 'C': 2, 'D': 3}
                correct_index = answer_map.get(correct_answer, 0)
                
                # Validate explanation
                explanation = row.get('Explanation', '').strip()
                if not explanation:
                    errors.append(ValidationError(question_id, "Empty explanation", 'error'))
                elif len(explanation) < 20:
                    errors.append(ValidationError(question_id, f"Explanation too short ({len(explanation)} chars, minimum 20)", 'warning'))
                elif len(explanation) > 500:
                    errors.append(ValidationError(question_id, f"Explanation too long ({len(explanation)} chars, maximum 500)", 'warning'))
                
                # Build question object
                question = {
                    "id": question_id,
                    "text": question_text,
                    "options": options,
                    "correctAnswer": correct_index,
                    "explanation": explanation,
                    "category": category,
                    "difficulty": difficulty,
                    "imageURL": row.get('Image_URL', '').strip() or None
                }
                
                questions.append(question)
        
    except FileNotFoundError:
        errors.append(ValidationError("FILE", f"CSV file not found: {csv_file}", 'error'))
        return [], errors
    except Exception as e:
        errors.append(ValidationError("FILE", f"Error reading CSV: {str(e)}", 'error'))
        return [], errors
    
    return questions, errors

def check_distribution(questions: List[Dict]) -> List[ValidationError]:
    """Check category distribution and balance"""
    errors = []
    
    # Count by category
    category_counts = Counter(q['category'] for q in questions)
    difficulty_counts = Counter(q['difficulty'] for q in questions)
    
    # Minimum questions per category for mock tests
    min_per_category = 3
    for category in VALID_CATEGORIES:
        count = category_counts.get(category, 0)
        if count < min_per_category:
            errors.append(ValidationError(
                "DISTRIBUTION",
                f"Category '{category}' has only {count} questions (minimum {min_per_category} recommended)",
                'warning'
            ))
    
    # Check difficulty balance (should have some of each)
    for difficulty in VALID_DIFFICULTIES:
        count = difficulty_counts.get(difficulty, 0)
        percentage = (count / len(questions) * 100) if questions else 0
        if percentage < 20:
            errors.append(ValidationError(
                "DISTRIBUTION",
                f"Only {percentage:.1f}% of questions are '{difficulty}' (recommend at least 20%)",
                'info'
            ))
    
    return errors

def generate_balanced_mock_test(questions: List[Dict], num_questions: int = 50) -> List[Dict]:
    """Generate a balanced mock test with proper category distribution"""
    import random
    
    # Group questions by category
    by_category = defaultdict(list)
    for q in questions:
        by_category[q['category']].append(q)
    
    # Target distribution (approximate DVSA test)
    target_distribution = {
        'roadAndTrafficSigns': 8,
        'rulesOfTheRoad': 6,
        'hazardAwareness': 6,
        'safetyAndYourVehicle': 5,
        'motorwayRules': 5,
        'vehicleHandling': 5,
        'vulnerableRoadUsers': 5,
        'safetyMargins': 4,
        'attitudeToOtherRoadUsers': 3,
        'alertness': 2,
        'otherTypesOfVehicle': 2,
        'essentialDocuments': 2,
        'incidents': 2,
        'vehicleLoading': 1
    }
    
    selected = []
    
    # Select questions according to distribution
    for category, target_count in target_distribution.items():
        available = by_category.get(category, [])
        if len(available) >= target_count:
            selected.extend(random.sample(available, target_count))
        else:
            # Not enough questions in this category, take all
            selected.extend(available)
    
    # If we don't have 50 yet, fill with random questions
    while len(selected) < num_questions and len(selected) < len(questions):
        remaining = [q for q in questions if q not in selected]
        if remaining:
            selected.append(random.choice(remaining))
        else:
            break
    
    # Shuffle the final selection
    random.shuffle(selected)
    
    return selected[:num_questions]

def save_json(questions: List[Dict], output_file: str, version: str = "1.0") -> None:
    """Save questions to JSON with versioning"""
    output = {
        "version": version,
        "lastUpdated": "2026-01-27",
        "totalQuestions": len(questions),
        "questions": questions
    }
    
    with open(output_file, 'w', encoding='utf-8') as file:
        json.dump(output, file, indent=2, ensure_ascii=False)

def print_report(questions: List[Dict], errors: List[ValidationError]) -> None:
    """Print validation report"""
    print("\n" + "="*80)
    print("📊 VALIDATION REPORT")
    print("="*80 + "\n")
    
    # Error summary
    error_count = sum(1 for e in errors if e.severity == 'error')
    warning_count = sum(1 for e in errors if e.severity == 'warning')
    info_count = sum(1 for e in errors if e.severity == 'info')
    
    if error_count > 0:
        print(f"❌ ERRORS: {error_count}")
        for error in [e for e in errors if e.severity == 'error']:
            print(f"   {error}")
        print()
    
    if warning_count > 0:
        print(f"⚠️  WARNINGS: {warning_count}")
        for error in [e for e in errors if e.severity == 'warning']:
            print(f"   {error}")
        print()
    
    if info_count > 0:
        print(f"ℹ️  INFO: {info_count}")
        for error in [e for e in errors if e.severity == 'info']:
            print(f"   {error}")
        print()
    
    # Statistics
    if questions:
        print("📈 STATISTICS")
        print(f"   Total questions: {len(questions)}")
        
        # Category breakdown
        category_counts = Counter(q['category'] for q in questions)
        print(f"\n   By Category:")
        for category in sorted(VALID_CATEGORIES):
            count = category_counts.get(category, 0)
            percentage = (count / len(questions) * 100) if questions else 0
            bar = "█" * int(percentage / 2)
            print(f"   {category:30s} {count:3d} ({percentage:5.1f}%) {bar}")
        
        # Difficulty breakdown
        difficulty_counts = Counter(q['difficulty'] for q in questions)
        print(f"\n   By Difficulty:")
        for diff in ['easy', 'medium', 'hard']:
            count = difficulty_counts.get(diff, 0)
            percentage = (count / len(questions) * 100) if questions else 0
            print(f"   {diff:10s} {count:3d} ({percentage:5.1f}%)")
        
        # Mock test capability
        mock_tests_possible = len(questions) // 50
        print(f"\n   Mock Tests Possible: {mock_tests_possible} (50 questions each)")
        
        print()
    
    # Final verdict
    print("="*80)
    if error_count == 0:
        print("✅ VALIDATION PASSED - Ready for conversion!")
    else:
        print("❌ VALIDATION FAILED - Fix errors before converting")
    print("="*80 + "\n")

def main():
    """Main validation and conversion process"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Validate and convert driving theory test questions')
    parser.add_argument('csv_file', help='Input CSV file (e.g., questions_master.csv)')
    parser.add_argument('-o', '--output', default='questions.json', help='Output JSON file')
    parser.add_argument('-v', '--version', default='1.0', help='Questions version number')
    parser.add_argument('--generate-mock', action='store_true', help='Generate sample mock test')
    parser.add_argument('--mock-output', default='mock_test_sample.json', help='Mock test output file')
    
    args = parser.parse_args()
    
    print(f"\n🔍 Validating: {args.csv_file}")
    print(f"📄 Output: {args.output}")
    print(f"🏷️  Version: {args.version}\n")
    
    # Validate
    questions, errors = validate_questions(args.csv_file)
    
    # Check distribution
    if questions:
        dist_errors = check_distribution(questions)
        errors.extend(dist_errors)
    
    # Print report
    print_report(questions, errors)
    
    # Check for blocking errors
    has_errors = any(e.severity == 'error' for e in errors)
    
    if has_errors:
        print("⛔ Cannot convert - fix errors first\n")
        sys.exit(1)
    
    # Save JSON
    if questions:
        save_json(questions, args.output, args.version)
        print(f"✅ Saved {len(questions)} questions to {args.output}\n")
        
        # Generate mock test if requested
        if args.generate_mock:
            mock_test = generate_balanced_mock_test(questions)
            with open(args.mock_output, 'w', encoding='utf-8') as f:
                json.dump({
                    "mockTest": mock_test,
                    "totalQuestions": len(mock_test),
                    "categoryDistribution": dict(Counter(q['category'] for q in mock_test))
                }, f, indent=2, ensure_ascii=False)
            print(f"✅ Generated balanced mock test: {args.mock_output}\n")
    
    sys.exit(0)

if __name__ == '__main__':
    main()
