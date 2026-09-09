codeunit 60126 "BH LyL Origenes Convert Sync"
{
    // Al convertir una Cotización de venta a Pedido (acción estándar "Convertir en pedido"),
    // el Pedido resultante recibe un No. de documento nuevo (de la serie de Pedidos, no
    // reutiliza el No. de la Cotización), y "LyL OrigenLP"/"LyL Multiplicadores_LP"
    // (extensión externa LyLVariantsExt) NO se recalculan ni se trasladan automáticamente
    // para ese nuevo No. de documento -- se validó contra producción (2026-09-09,
    // cotización C04000 -> pedido P01414) que "totalFob" de Pag60120.origenesLP.al da 0
    // para todos los orígenes hasta correr manualmente la acción "Calcular Precios de
    // Venta" (Codeunit 80701 "LyLUnitPriceCalculation", procedure CalculateSalesPrice)
    // sobre el Pedido nuevo -- tras eso, los 8 orígenes de ese pedido coincidieron exacto
    // contra el "Reporte por Origenes" nativo.
    //
    // Este subscriber automatiza esa llamada para que el Pedido quede recalculado sin
    // intervención manual, ya que un flujo de Power Automate depende de leer "totalFob"
    // inmediatamente después de la conversión (ver docs/diseños si se documenta luego).
    //
    // Punto de enganche: OnAfterOnRun de "Sales-Quote to Order" (codeunit 86, Microsoft
    // Base Application) -- dispara al final de TODA la conversión, con el Pedido ya
    // insertado y sus líneas ya transferidas, así que "SalesOrderHeader" trae el No. de
    // documento definitivo.
    //
    // Pendiente de validar (no verificado contra el código fuente de LyLVariantsExt, que
    // no tenemos -- solo se dedujo del nombre del procedimiento frente al caption del
    // botón "Calcular Precios de Venta"): si CalculateSalesPrice no alcanza a crear los
    // registros "LyL OrigenLP" del Pedido nuevo en algún caso, falta además replicar lo
    // que hace el botón "Ajustar Origen" (LyL Origenes) -- no identificado, LyLVariantsExt
    // no expone ese procedimiento como público en los símbolos compilados.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Quote to Order", OnAfterOnRun, '', false, false)]
    local procedure RecalculateLylOnAfterConvertToOrder(var SalesHeader: Record "Sales Header"; var SalesOrderHeader: Record "Sales Header")
    begin
        LylUnitPriceCalculation.CalculateSalesPrice(SalesOrderHeader."No.");
    end;

    var
        LylUnitPriceCalculation: Codeunit LyLUnitPriceCalculation;
}
