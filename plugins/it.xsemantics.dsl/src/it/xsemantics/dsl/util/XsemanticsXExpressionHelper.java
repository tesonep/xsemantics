package it.xsemantics.dsl.util;

import it.xsemantics.dsl.typing.XsemanticsTypingSystem;
import it.xsemantics.dsl.xsemantics.EnvironmentAccess;
import it.xsemantics.dsl.xsemantics.Fail;
import it.xsemantics.dsl.xsemantics.OrExpression;
import it.xsemantics.dsl.xsemantics.RuleInvocation;

import org.eclipse.emf.ecore.EObject;
import org.eclipse.xtext.xbase.XExpression;
import org.eclipse.xtext.xbase.util.XExpressionHelper;

import com.google.inject.Inject;

@SuppressWarnings("restriction")
public class XsemanticsXExpressionHelper extends XExpressionHelper {

	@Inject
	protected XsemanticsTypingSystem typingSystem;

	@Override
	public boolean hasSideEffects(XExpression expr) {
		if (typingSystem.isBooleanPremise(expr)) {
			// in this case we consider it valid
			// since it will be generated to a correct Java statement
			return true;
		}
		if (isXsemanticsXExpression(expr)) {
			// in this case we consider it valid
			// since it will be generated to a correct Java statement
			return true;
		}
		return super.hasSideEffects(expr);
	}

	public boolean isXsemanticsXExpression(EObject eObject) {
		return eObject instanceof EnvironmentAccess
				|| eObject instanceof RuleInvocation
				|| eObject instanceof OrExpression || eObject instanceof Fail;
	}
}