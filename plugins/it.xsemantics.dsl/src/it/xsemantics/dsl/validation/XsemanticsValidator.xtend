/*
 * generated by Xtext
 */
package it.xsemantics.dsl.validation

import com.google.inject.Inject
import it.xsemantics.dsl.typing.TupleType
import it.xsemantics.dsl.typing.XsemanticsTypeSystem
import it.xsemantics.dsl.util.XsemanticsNodeModelUtils
import it.xsemantics.dsl.util.XsemanticsUtils
import it.xsemantics.dsl.util.XsemanticsXExpressionHelper
import it.xsemantics.dsl.xsemantics.AuxiliaryDescription
import it.xsemantics.dsl.xsemantics.AuxiliaryFunction
import it.xsemantics.dsl.xsemantics.CheckRule
import it.xsemantics.dsl.xsemantics.JudgmentDescription
import it.xsemantics.dsl.xsemantics.JudgmentParameter
import it.xsemantics.dsl.xsemantics.Rule
import it.xsemantics.dsl.xsemantics.RuleConclusionElement
import it.xsemantics.dsl.xsemantics.RuleInvocation
import it.xsemantics.dsl.xsemantics.RuleParameter
import it.xsemantics.dsl.xsemantics.XsemanticsPackage
import it.xsemantics.dsl.xsemantics.XsemanticsSystem
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EStructuralFeature
import org.eclipse.xtext.common.types.JvmFormalParameter
import org.eclipse.xtext.common.types.JvmTypeReference
import org.eclipse.xtext.common.types.TypesPackage
import org.eclipse.xtext.validation.Check
import org.eclipse.xtext.validation.ValidationMessageAcceptor
import org.eclipse.xtext.xbase.XAssignment
import org.eclipse.xtext.xbase.XClosure
import org.eclipse.xtext.xbase.XExpression
import org.eclipse.xtext.xbase.XFeatureCall
import org.eclipse.xtext.xbase.XReturnExpression
import org.eclipse.xtext.xbase.XThrowExpression
import org.eclipse.xtext.xbase.XbasePackage
import org.eclipse.xtext.xbase.lib.IterableExtensions
import org.eclipse.xtext.xbase.typesystem.util.Multimaps2

import static extension org.eclipse.xtext.EcoreUtil2.*

//import org.eclipse.xtext.validation.Check

/**
 * Custom validation rules. 
 *
 * see http://www.eclipse.org/Xtext/documentation.html#validation
 */
class XsemanticsValidator extends AbstractXsemanticsValidator {

	@Inject
	protected XsemanticsTypeSystem typeSystem;

	@Inject
	protected extension XsemanticsUtils;

	@Inject
	protected XsemanticsXExpressionHelper xExpressionHelper;

	@Inject
	protected XsemanticsNodeModelUtils nodeModelUtils;

	public final static int maxOfOutputParams = 3;

	protected boolean enableWarnings = true;

	@Check
	override void checkAssignment(XAssignment assignment) {
		// we allow assignment to output parameters
		val assignmentFeature = assignment.getFeature();
		if (assignmentFeature instanceof JvmFormalParameter) {
			if (assignmentFeature.isInputParam()) {
				error("Assignment to input parameter",
						XbasePackage.Literals.XASSIGNMENT__ASSIGNABLE,
						ValidationMessageAcceptor.INSIGNIFICANT_INDEX,
						IssueCodes.ASSIGNMENT_TO_INPUT_PARAM);
			}
			return;
		}
		super.checkAssignment(assignment);
	}

	@Check
	override void checkReturn(XReturnExpression expr) {
		error("Return statements are not allowed here", expr, null,
				IssueCodes.RETURN_NOT_ALLOWED);
	}

//	@Override
//	protected boolean supportsCheckedExceptions() {
//		// we generate Java code which already handles exceptions
//		return false;
//	}

	def protected boolean isContainedInAuxiliaryFunction(XExpression expr) {
		return expr.getContainerOfType(AuxiliaryFunction) != null
	}

	override protected boolean isImplicitReturn(XExpression expr) {
		if (expr.isContainedInAuxiliaryFunction()) {
			return super.isImplicitReturn(expr);
		}

		// we will deal with this during generation
		return false;
	}

	@Check
	def void checkThrow(XThrowExpression expr) {
		error("Throw statements are not allowed here", expr, null,
				IssueCodes.THROW_NOT_ALLOWED);
	}

	override protected boolean isLocallyUsed(EObject target, EObject containerToFindUsage) {
		if (containerToFindUsage instanceof RuleInvocation) {
			// we don't want warning when a variable declaration appears as
			// output argument: it is implicitly used for the result
			return true;
		}
		return super.isLocallyUsed(target, containerToFindUsage);
	}

	override protected boolean isValueExpectedRecursive(XExpression expr) {
		// this is used by Xbase validator to check expressions with
		// side effects, by inspecting expr's container
		// so we must customize it when the container is one of our
		// custom XExpressions
		val valueExpectedRecursive = super
				.isValueExpectedRecursive(expr);
		return valueExpectedRecursive
				|| xExpressionHelper.isXsemanticsXExpression(expr.eContainer());
	}

	@Check
	def void checkJudgmentDescription(JudgmentDescription judgmentDescription) {
		checkNoDuplicateJudgmentDescriptionSymbols(judgmentDescription);
		checkNumOfOutputParams(judgmentDescription);
		checkInputParams(judgmentDescription);
		checkJudgmentDescriptionRules(judgmentDescription)
	}

	def void checkJudgmentDescriptionRules(
			JudgmentDescription judgmentDescription) {
		if (judgmentDescription.isOverride())
			return;
		if (enableWarnings
				&& judgmentDescription.rulesForJudgmentDescription(
						).isEmpty()) {
			warning("No rule defined for the judgment description",
					XsemanticsPackage.Literals.JUDGMENT_DESCRIPTION
							.getEIDAttribute(),
					IssueCodes.NO_RULE_FOR_JUDGMENT_DESCRIPTION);
		}
	}

	def protected void checkNoDuplicateJudgmentDescriptionSymbols(
			JudgmentDescription judgmentDescription) {
		val judgmentSymbol = judgmentDescription.getJudgmentSymbol();
		val relationSymbols = judgmentDescription.getRelationSymbols();
		if (judgmentDescription.containingSystem().getJudgmentDescriptions(
				judgmentSymbol, relationSymbols).size() > 1) {
			error("Duplicate JudgmentDescription symbols: "
					+ symbolsRepresentation(judgmentSymbol, relationSymbols),
					XsemanticsPackage.Literals.JUDGMENT_DESCRIPTION__JUDGMENT_SYMBOL,
					IssueCodes.DUPLICATE_JUDGMENT_DESCRIPTION_SYMBOLS);
		}
	}

	def protected void checkNumOfOutputParams(
			JudgmentDescription judgmentDescription) {
		if (judgmentDescription.outputJudgmentParameters()
				.size() > maxOfOutputParams) {
			error("No more than " + maxOfOutputParams
					+ " output parameters are handled at the moment",
					XsemanticsPackage.Literals.JUDGMENT_DESCRIPTION__JUDGMENT_PARAMETERS,
					IssueCodes.TOO_MANY_OUTPUT_PARAMS);
		}
	}

	def protected void checkInputParams(JudgmentDescription judgmentDescription) {
		val inputParams = judgmentDescription.inputParams()
		if (inputParams.empty) {
			error("No input parameter; at least one is needed",
					XsemanticsPackage.Literals.JUDGMENT_DESCRIPTION__JUDGMENT_PARAMETERS,
					IssueCodes.NO_INPUT_PARAM);
		} else {
			inputParams.checkDuplicateNames
		}
	}

	@Check
	def void checkRule(Rule rule) {
		val judgmentDescription = checkRuleConformantToJudgmentDescription(rule);
		if (judgmentDescription != null) {
			val judgmentParameters = judgmentDescription
					.getJudgmentParameters();
			val conclusionElements = rule
					.getConclusion().getConclusionElements();
			// judgmentParameters.size() == conclusionElements.size())
			// otherwise we could not find a JudgmentDescription for the rule
			val judgmentParametersIt = judgmentParameters
					.iterator();
			for (RuleConclusionElement ruleConclusionElement : conclusionElements) {
				if (!judgmentParametersIt.next().isOutputParameter()
						&& !(ruleConclusionElement instanceof RuleParameter)) {
					error("Must be a parameter, not an expression",
							ruleConclusionElement,
							XsemanticsPackage.Literals.RULE_CONCLUSION_ELEMENT
									.getEIDAttribute(),
							IssueCodes.NOT_PARAMETER);
				}
			}
		}
	}

	@Check
	def public void checkValidOverride(Rule rule) {
		val system = rule.containingSystem();
		if (system != null) {
			if (rule.isOverride()) {
				val superSystem = system.superSystemDefinition();
				if (superSystem == null) {
					error("Cannot override rule without system 'extends'",
							rule, XsemanticsPackage.Literals.RULE__OVERRIDE,
							IssueCodes.OVERRIDE_WITHOUT_SYSTEM_EXTENDS);
				} else {
					val rulesOfTheSameKind = superSystem
							.allRulesOfTheSameKind(rule);
					val tupleType = typeSystem.getInputTypes(rule);
					var Rule ruleToOverride = rulesOfTheSameKind.findFirst[
						val tupleType2 = typeSystem.getInputTypes(it);
						typeSystem.equals(tupleType, tupleType2, rule)
					]
					if (ruleToOverride == null) {
						error("No rule of the same kind to override: "
								+ tupleTypeRepresentation(tupleType), rule,
								XsemanticsPackage.Literals.RULE__OVERRIDE,
								IssueCodes.NO_RULE_TO_OVERRIDE_OF_THE_SAME_KIND);
					} else if (!ruleToOverride.getName().equals(rule.getName())) {
						error("Must have the same name of the rule to override: "
								+ ruleToOverride.getName(),
								rule,
								XsemanticsPackage.Literals.RULE__OVERRIDE,
								IssueCodes.OVERRIDE_RULE_MUST_HAVE_THE_SAME_NAME);
					}
				}
			}
		}
	}

	@Check
	def void checkValidOverride(CheckRule rule) {
		val system = rule.containingSystem();
		if (system != null) {
			if (rule.isOverride()) {
				val superSystem = system.superSystemDefinition();
				if (superSystem == null) {
					error("Cannot override checkrule without system 'extends'",
							rule,
							XsemanticsPackage.Literals.CHECK_RULE__OVERRIDE,
							IssueCodes.OVERRIDE_WITHOUT_SYSTEM_EXTENDS);
				} else {
					val inheritedCheckRules = superSystem.allCheckRules();
					var CheckRule inheritedRule = inheritedCheckRules.findFirst[
						typeSystem.equals(rule.getElement().getParameter()
								.getParameterType(), it.getElement()
								.getParameter().getParameterType(), rule)
								&& rule.getName().equals(it.getName())
						]
					
					if (inheritedRule == null)
						error("No checkrule to override: " + rule.getName(),
								rule,
								XsemanticsPackage.Literals.CHECK_RULE__OVERRIDE,
								IssueCodes.NO_RULE_TO_OVERRIDE_OF_THE_SAME_KIND);
				}
			}
		}
	}

	@Check
	def public void checkValidOverride(JudgmentDescription judgment) {
		val system = judgment.containingSystem();
		if (system != null) {
			if (judgment.isOverride()) {
				val superSystem = system
						.superSystemDefinition();
				if (superSystem == null) {
					error("Cannot override judgment without system 'extends'",
							judgment,
							XsemanticsPackage.Literals.JUDGMENT_DESCRIPTION__OVERRIDE,
							IssueCodes.OVERRIDE_WITHOUT_SYSTEM_EXTENDS);
				} else {
					val inheritedJudgments = superSystem
							.allJudgments(
									judgment.getJudgmentSymbol(),
									judgment.getRelationSymbols());
					val judgmentToOverride = inheritedJudgments.findFirst[
						typeSystem.equals(judgment, it)
					]
					if (judgmentToOverride == null) {
						error("No judgment of the same kind to override: "
								+ nodeModelUtils.getProgramText(judgment),
								judgment,
								XsemanticsPackage.Literals.JUDGMENT_DESCRIPTION__OVERRIDE,
								IssueCodes.NO_JUDGMENT_TO_OVERRIDE_OF_THE_SAME_KIND);
					} else if (!judgmentToOverride.getName().equals(
							judgment.getName())) {
						error("Must have the same name of the judgment to override: "
								+ judgmentToOverride.getName(),
								judgment,
								XsemanticsPackage.Literals.JUDGMENT_DESCRIPTION__OVERRIDE,
								IssueCodes.OVERRIDE_JUDGMENT_MUST_HAVE_THE_SAME_NAME);
					}
				}
			}
		}
	}

	@Check
	def public void checkRuleInvocation(RuleInvocation ruleInvocation) {
		val judgmentDescription = checkRuleInvocationConformantToJudgmentDescription(ruleInvocation);
		if (judgmentDescription != null) {
			val judgmentParameters = judgmentDescription
					.getJudgmentParameters();
			val invocationExpressions = ruleInvocation
					.getExpressions();
			// judgmentParamters.size() == conclusionElements.size())
			// otherwise we could not find a JudgmentDescription for the rule
			val judgmentParametersIt = judgmentParameters
					.iterator();
			for (XExpression ruleInvocationExpression : invocationExpressions) {
				if (judgmentParametersIt
						.next().isOutputParameter()) {
					if (!ruleInvocationExpression
							.validOutputArgExpression()) {
						error("Not a valid argument for output parameter: "
								+ nodeModelUtils
										.getProgramText(ruleInvocationExpression),
								ruleInvocationExpression,
								null,
								IssueCodes.NOT_VALID_OUTPUT_ARG);
					}
				} else {
					if (!ruleInvocationExpression
							.validInputArgExpression()) {
						error("Not a valid argument for input parameter: "
								+ nodeModelUtils
										.getProgramText(ruleInvocationExpression),
								ruleInvocationExpression,
								null,
								IssueCodes.NOT_VALID_INPUT_ARG);
					}
				}

			}
		}
	}

	@Check
	def public void checkSystem(XsemanticsSystem system) {
		val validatorExtends = system
				.getValidatorExtends();
		if (validatorExtends != null) {
			if (!typeSystem.isAbstractDeclarativeValidator(validatorExtends,
					system)) {
				error("Not an AbstractDeclarativeValidator: "
						+ getNameOfTypes(validatorExtends),
						XsemanticsPackage.Literals.XSEMANTICS_SYSTEM__VALIDATOR_EXTENDS,
						IssueCodes.NOT_VALIDATOR);
			}
		}
		val superSystem = system.getSuperSystem();
		if (superSystem != null) {
			if (!typeSystem.isValidSuperSystem(superSystem, system)) {
				error("Not an Xsemantics system: "
						+ getNameOfTypes(superSystem),
						XsemanticsPackage.Literals.XSEMANTICS_SYSTEM__SUPER_SYSTEM,
						IssueCodes.NOT_VALID_SUPER_SYSTEM);
			}
			if (validatorExtends != null) {
				error("system 'extends' cannot coexist with 'validatorExtends'",
						XsemanticsPackage.Literals.XSEMANTICS_SYSTEM__SUPER_SYSTEM,
						IssueCodes.EXTENDS_CANNOT_COEXIST_WITH_VALIDATOR_EXTENDS);
				error("system 'extends' cannot coexist with 'validatorExtends'",
						XsemanticsPackage.Literals.XSEMANTICS_SYSTEM__VALIDATOR_EXTENDS,
						IssueCodes.EXTENDS_CANNOT_COEXIST_WITH_VALIDATOR_EXTENDS);
			}
		}

		val superSystems = system
				.allSuperSystemDefinitions();
		if (superSystems.contains(system)) {
			error("Cycle in extends relation",
					XsemanticsPackage.Literals.XSEMANTICS_SYSTEM__SUPER_SYSTEM,
					IssueCodes.CYCLIC_HIERARCHY);
		}
		
		val allSuperJudgments = system.superSystemDefinition?.allJudgments
		if (allSuperJudgments != null) {
			val superJudgmentsMap = allSuperJudgments.toMap[name]
			for (j : system.judgmentDescriptions) {
				if (!j.override) {
					val overridden = superJudgmentsMap.get(j.name)
					if (overridden != null)
						error(
							"Judgment '" + j.name + "' must override judgment" +
								reportContainingSystemName(overridden),
							j,
							XsemanticsPackage.Literals.JUDGMENT_DESCRIPTION__NAME, 
							IssueCodes.DUPLICATE_JUDGMENT_NAME);
				}
			}
		}
		
		val elements = system.injections + 
			system.judgmentDescriptions +
			system.auxiliaryDescriptions +
			// system.auxiliaryFunctions + 
			// aux functions have the same name of aux descriptions
			system.rules + 
			system.checkrules
		elements.checkDuplicateNames()
	}

	def private <T extends EObject> checkDuplicateNames(Iterable<T> collection) {
		if (!collection.empty) {
			val map = <String,EObject>Multimaps2::newLinkedHashListMultimap
			for (e : collection) {
				map.put(XsemanticsNameComputer.computeName(e), e)
			}

			for (entry : map.asMap.entrySet) {
				val duplicates = entry.value
				if (duplicates.size > 1) {
					for (d : duplicates)
						error(
							"Duplicate name '" + entry.key + "' (" + d.eClass.name + ")",
							d,
							null, 
							IssueCodes.DUPLICATE_NAME);
				}
			}
		}
	}

	@Check
	def protected void checkNoDuplicateCheckRulesFromSupersystem(CheckRule rule) {
		if (rule.isOverride())
			return;
		val system = rule.containingSystem().superSystemDefinition();
		if (system != null) {
			val rulesWithTheSameName = system
					.allCheckRulesByName(rule);
			for (CheckRule checkRule : rulesWithTheSameName) {
				error("Duplicate checkrule with the same name"
						+ reportContainingSystemName(checkRule),
						XsemanticsPackage.Literals.CHECK_RULE__NAME,
						IssueCodes.DUPLICATE_RULE_NAME);
			}
		}
	}

	@Check
	def protected void checkNoDuplicateRulesWithSameArguments(Rule rule) {
		val rulesOfTheSameKind = rule
				.allRulesOfTheSameKind();
		if (rulesOfTheSameKind.size() > 1) {
			val tupleType = typeSystem.getInputTypes(rule);
			for (Rule rule2 : rulesOfTheSameKind) {
				if (rule2 != rule && !rule.isOverride()) {
					val tupleType2 = typeSystem.getInputTypes(rule2);
					if (typeSystem.equals(tupleType, tupleType2, rule)) {
						error("Duplicate rule of the same kind with parameters: "
								+ tupleTypeRepresentation(tupleType)
								+ reportContainingSystemName(rule2),
								XsemanticsPackage.Literals.RULE__CONCLUSION,
								IssueCodes.DUPLICATE_RULE_WITH_SAME_ARGUMENTS);
					}
				}
			}
		}
	}

	@Check
	def public void checkAuxiliaryFunctions(AuxiliaryDescription aux) {
		val functionsForAuxiliaryDescrition = aux.functionsForAuxiliaryDescrition();
		if (enableWarnings
				&& functionsForAuxiliaryDescrition
						.isEmpty()) {
			warning("No function defined for the auxiliary description",
					XsemanticsPackage.Literals.AUXILIARY_DESCRIPTION
							.getEIDAttribute(),
					IssueCodes.NO_AUXFUN_FOR_AUX_DESCRIPTION);
		}
		
		if (functionsForAuxiliaryDescrition.size() > 1) {
			for (AuxiliaryFunction auxiliaryFunction : functionsForAuxiliaryDescrition) {
				val tupleType = typeSystem.getInputTypes(auxiliaryFunction);
				
				for (AuxiliaryFunction auxiliaryFunction2 : functionsForAuxiliaryDescrition) {
					val tupleType2 = typeSystem.getInputTypes(auxiliaryFunction2);
					if (auxiliaryFunction !== auxiliaryFunction2 && typeSystem.equals(tupleType, tupleType2, auxiliaryFunction)) {
						error("Duplicate auxiliary function of the same kind with parameters: "
								+ tupleTypeRepresentation(tupleType)
								+ reportContainingSystemName(auxiliaryFunction2),
								auxiliaryFunction2,
								XsemanticsPackage.Literals.AUXILIARY_FUNCTION__PARAMETERS,
								IssueCodes.DUPLICATE_AUXFUN_WITH_SAME_ARGUMENTS);
					}
				}
			}
		}
	}

	@Check
	def public void checkAuxiliaryFunctionHasAuxiliaryDescription(
			AuxiliaryFunction aux) {
		val auxiliaryDescription = aux
				.auxiliaryDescription();
		if (auxiliaryDescription == null) {
			error("No auxiliary description for auxiliary function '"
					+ aux.getName() + "'",
					XsemanticsPackage.Literals.AUXILIARY_FUNCTION__NAME,
					IssueCodes.NO_AUXDESC_FOR_AUX_FUNCTION);
		} else
			checkConformanceOfAuxiliaryFunction(aux, auxiliaryDescription);
	}

	@Check
	def public void checkOutputParamAccessWithinClosure(XFeatureCall featureCall) {
		val feature = featureCall.getFeature();
		if (feature instanceof JvmFormalParameter) {
			val container = feature.eContainer();
			if (container instanceof RuleParameter) {
				if ((container as RuleParameter).isOutputParam
						&& insideClosure(featureCall)) {
					error("Cannot refer to an output parameter "
							+ feature.getIdentifier()
							+ " from within a closure", featureCall, null,
							IssueCodes.ACCESS_TO_OUTPUT_PARAM_WITHIN_CLOSURE);
				}
			}
			return;
		}
	}

	def private boolean insideClosure(XFeatureCall featureCall) {
		return featureCall.getContainerOfType(XClosure) != null;
	}

	def protected void checkConformanceOfAuxiliaryFunction(AuxiliaryFunction aux,
			AuxiliaryDescription auxiliaryDescription) {
		val funParams = aux.getParameters();
		val descParams = auxiliaryDescription
				.getParameters();

		if (funParams.size() != descParams.size()) {
			error("expected " + descParams.size() + " parameter(s), but was "
					+ funParams.size(),
					aux,
					XsemanticsPackage.Literals.AUXILIARY_FUNCTION__PARAMETERS,
					IssueCodes.PARAMS_SIZE_DONT_MATCH);
		} else {
			val funParamsIt = funParams.iterator();
			for (JvmFormalParameter jvmFormalParameter : descParams) {
				val expected = typeSystem
						.getType(jvmFormalParameter);
				val funParam = funParamsIt.next();
				val actual = typeSystem.getType(funParam);
				if (!typeSystem.isConformant(expected, actual, funParam)) {
					error("parameter type "
							+ getNameOfTypes(actual)
							+ " is not subtype of AuxiliaryDescription declared type "
							+ getNameOfTypes(expected),
							funParam,
							TypesPackage.Literals.JVM_FORMAL_PARAMETER__PARAMETER_TYPE,
							IssueCodes.NOT_SUBTYPE);
				}
			}
		}
	}

	def protected String reportContainingSystemName(EObject object) {
		return ", in system: "
				+ object.containingSystem().getName();
	}

	def protected JudgmentDescription checkRuleConformantToJudgmentDescription(
			Rule rule) {
		val conclusion = rule.getConclusion();
		return checkConformanceAgainstJudgmentDescription(conclusion,
				conclusion.getJudgmentSymbol(),
				conclusion.getRelationSymbols(),
				conclusion.getConclusionElements(), "Rule conclusion",
				XsemanticsPackage.Literals.RULE__CONCLUSION,
				XsemanticsPackage.Literals.RULE_CONCLUSION_ELEMENT
						.getEIDAttribute());
	}

	def protected JudgmentDescription checkRuleInvocationConformantToJudgmentDescription(
			RuleInvocation ruleInvocation) {
		return checkConformanceAgainstJudgmentDescription(
				ruleInvocation,
				ruleInvocation.getJudgmentSymbol(),
				ruleInvocation.getRelationSymbols(),
				ruleInvocation.getExpressions(),
				"Rule invocation",
				XsemanticsPackage.Literals.RULE_INVOCATION.getEIDAttribute(),
				null);
	}

	def protected JudgmentDescription checkConformanceAgainstJudgmentDescription(
			EObject element, String judgmentSymbol,
			Iterable<String> relationSymbols,
			Iterable<? extends EObject> elements,
			String elementDescription, EStructuralFeature elementFeature,
			EStructuralFeature conformanceFeature) {
		val judgmentDescription = element
				.judgmentDescription(judgmentSymbol, relationSymbols);
		if (judgmentDescription == null) {
			error("No Judgment description for: "
					+ symbolsRepresentation(judgmentSymbol, relationSymbols),
					elementFeature, IssueCodes.NO_JUDGMENT_DESCRIPTION);
		} else {
			val judgmentParameters = judgmentDescription
					.getJudgmentParameters();
			val elementsIt = elements.iterator();
			for (judgmentParameter : judgmentParameters) {
				// the rule might still be incomplete, thus we must check
				// whether there is an element to check against.
				// Recall that the judgment has been searched for using only
				// the symbols, not the rule conclusion elements
				if (elementsIt.hasNext())
					checkConformance(judgmentParameter, elementsIt.next(),
						elementDescription, conformanceFeature);
			}
		}
		return judgmentDescription;
	}

	def protected void checkConformance(JudgmentParameter judgmentParameter,
			EObject element, String elementDescription,
			EStructuralFeature feature) {
		val expected = typeSystem.getType(judgmentParameter);
		val actual = typeSystem.getType(element);
		if (!typeSystem.isConformant(expected, actual, element)) {
			error(elementDescription + " type " + getNameOfTypes(actual)
					+ " is not subtype of JudgmentDescription declared type "
					+ getNameOfTypes(expected), element, feature,
					IssueCodes.NOT_SUBTYPE);
		}
	}

	def protected String symbolsRepresentation(String judgmentSymbol,
			Iterable<String> relationSymbols) {
		return judgmentSymbol + " "
				+ IterableExtensions.join(relationSymbols, " ");
	}

	def protected String tupleTypeRepresentation(TupleType tupleType) {
		val builder = new StringBuilder();
		val it = tupleType.iterator();
		while (it.hasNext()) {
			builder.append(getNameOfTypes(it.next()));
			if (it.hasNext())
				builder.append(", ");
		}
		return builder.toString();
	}

	def private Object getNameOfTypes(JvmTypeReference typeRef) {
		return if (typeRef == null)  "<null>" else typeRef.getSimpleName();
	}

	def public boolean isEnableWarnings() {
		return enableWarnings;
	}

	def public void setEnableWarnings(boolean enableWarnings) {
		this.enableWarnings = enableWarnings;
	}
	
}
