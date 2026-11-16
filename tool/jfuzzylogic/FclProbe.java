import net.sourceforge.jFuzzyLogic.FIS;
import net.sourceforge.jFuzzyLogic.FunctionBlock;
import net.sourceforge.jFuzzyLogic.defuzzifier.DefuzzifierContinuous;
import net.sourceforge.jFuzzyLogic.rule.*;

/** Original test adapter; jFuzzyLogic remains a separate, unmodified dependency. */
public final class FclProbe {
  public static void main(String[] args) {
    DefuzzifierContinuous.DEFAULT_NUMBER_OF_POINTS = Integer.parseInt(args[3]);
    FIS fis = FIS.load(args[0], true);
    if (fis == null) throw new IllegalArgumentException("FCL parse failed");
    FunctionBlock block = fis.getFunctionBlock(null);
    block.setVariable("temperature", Double.parseDouble(args[1]));
    block.setVariable("humidity", Double.parseDouble(args[2]));
    block.evaluate();
    Variable output = block.getVariable("fan");
    DefuzzifierContinuous defuzz = (DefuzzifierContinuous)output.getDefuzzifier();
    StringBuilder json = new StringBuilder("{\"rawValue\":"+output.getValue());
    json.append(",\"min\":").append(output.getUniverseMin());
    json.append(",\"max\":").append(output.getUniverseMax());
    json.append(",\"step\":").append(defuzz.getStepSize());
    json.append(",\"memberships\":{");
    boolean firstVariable = true;
    for (String name : new String[]{"temperature", "humidity"}) {
      if (!firstVariable) json.append(','); firstVariable = false;
      json.append('"').append(name).append("\":{");
      boolean first = true;
      Variable input = block.getVariable(name);
      for (String term : input.getLinguisticTerms().keySet()) {
        if (!first) json.append(','); first = false;
        json.append('"').append(term).append("\":").append(input.getMembership(term));
      }
      json.append('}');
    }
    json.append("},\"strengths\":[");
    boolean first = true;
    double endpoint = 0;
    for (RuleBlock rules : block.getRuleBlocks().values()) {
      for (Rule rule : rules.getRules()) {
        if (!first) json.append(','); first = false;
        json.append(rule.getDegreeOfSupport());
        for (RuleTerm term : rule.getConsequents()) {
          double degree = output.getMembershipFunction(term.getTermName()).membership(output.getUniverseMax());
          endpoint = Math.max(endpoint, Math.min(rule.getDegreeOfSupport(), degree));
        }
      }
    }
    json.append("],\"endpointDegree\":").append(endpoint).append(",\"degrees\":[");
    double[] curve = defuzz.getValues();
    for (int i=0; i<curve.length; i++) {if(i>0)json.append(',');json.append(curve[i]);}
    json.append("]}");
    System.out.println(json);
  }
}
