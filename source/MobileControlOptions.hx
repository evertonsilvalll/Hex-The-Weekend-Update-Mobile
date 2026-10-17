package;

import Options.Option;

class MobileControlModeOption extends Option
{
	public function new()
	{
		super();
		description = "Escolha hitbox em quatro faixas ou botoes de direcao para jogar por toque.";
	}

	public override function press():Bool
	{
		MobileControlSettings.toggleMode();
		display = updateDisplay();
		return true;
	}

	public override function left():Bool
	{
		return press();
	}

	public override function right():Bool
	{
		return press();
	}

	private override function updateDisplay():String
	{
		return "Toque: " + (MobileControlSettings.useHitbox() ? "Hitbox" : "Botoes");
	}
}

class MobileHitboxVisibilityOption extends Option
{
	public function new()
	{
		super();
		description = "Mostre ou esconda as faixas da hitbox. O toque continua funcionando quando estao invisiveis.";
	}

	public override function press():Bool
	{
		MobileControlSettings.toggleVisibility();
		display = updateDisplay();
		return true;
	}

	public override function left():Bool
	{
		return press();
	}

	public override function right():Bool
	{
		return press();
	}

	private override function updateDisplay():String
	{
		return "Hitbox visivel: " + (MobileControlSettings.hitboxesVisible() ? "Sim" : "Nao");
	}
}
